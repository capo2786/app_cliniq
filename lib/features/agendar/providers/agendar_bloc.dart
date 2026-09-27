import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../../core/network/errores.dart';
import '../../citas/data/models/cita.dart';
import '../../dependientes/data/dependientes_service.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/portal_service.dart';
import '../dominio/horarios.dart';
import '../dominio/huecos.dart';
import 'agendar_event.dart';
import 'agendar_state.dart';

const String avisoHorarioTomado =
    'Ese horario acaba de ocuparse. Elige otro de la lista actualizada.';

/// El agendamiento paso a paso: para quién, qué médico, qué modalidad, qué
/// día y hora, el motivo, y confirmar.
///
/// La pantalla lo crea en cada visita —como las salas en UCEBell— para que
/// los médicos y lo ocupado lleguen frescos cada vez. Las reglas de qué
/// horarios se ofrecen viven en `dominio/huecos.dart`; aquí solo se decide
/// cuándo se piden los datos y a qué paso se va.
class AgendarBloc extends Bloc<AgendarEvent, AgendarState> {
  final PortalService _portal;
  final DependientesService _dependientes;
  final RelojClinica _reloj;
  final String _uid;

  /// [reglas] son las de la configuración de la clínica; [especialidades] y
  /// [ciudades], los catálogos que ordenan los filtros.
  AgendarBloc({
    required this._portal,
    required this._dependientes,
    required this._uid,
    required String nombreTitular,
    required ReglasAgendamiento reglas,
    List<String> especialidades = const [],
    List<String> ciudades = const [],
    bool puedeDependientes = true,
    RelojClinica? reloj,
  }) : _reloj = reloj ?? RelojClinica(),
       super(
         AgendarState(
           ahora: (reloj ?? RelojClinica()).ahora(),
           reglas: reglas,
           especialidades: especialidades,
           catalogoCiudades: ciudades,
           nombreTitular: nombreTitular,
           puedeDependientes: puedeDependientes,
         ),
       ) {
    on<AgendarIniciado>(_alIniciar);
    on<AgendarParaElegido>(_alElegirPara);
    on<AgendarFiltrosCambiados>(_alFiltrar);
    on<AgendarMedicoElegido>(_alElegirMedico);
    on<AgendarModalidadElegida>(_alElegirModalidad);
    on<AgendarFechaElegida>(_alElegirFecha);
    on<AgendarHuecoElegido>(_alElegirHueco);
    on<AgendarMotivoCambiado>(_alCambiarMotivo);
    on<AgendarPasoCambiado>(_alCambiarPaso);
    on<AgendarContinuado>(_alContinuar);
    on<AgendarRetrocedido>(_alRetroceder);
    on<AgendarConfirmado>(_alConfirmar);
    on<AgendarOcupadosReintentados>((event, emit) => _cargarOcupados(emit));
    on<AgendarDependientesRecargados>(_alRecargarDependientes);
    on<AgendarOtraCita>(_alEmpezarOtra);
  }

  DateTime get _ahora => _reloj.ahora();

  // ── Carga inicial ──────────────────────────────────────────────────

  Future<void> _alIniciar(
    AgendarIniciado event,
    Emitter<AgendarState> emit,
  ) async {
    emit(state.copiarCon(cargando: true, limpiarError: true, ahora: _ahora));

    try {
      final medicos = await _portal.medicos();

      final dependientes = state.puedeDependientes
          ? await _listarDependientes()
          : state.dependientes;

      var siguiente = state.copiarCon(
        cargando: false,
        medicos: medicos,
        dependientes: dependientes,
        ahora: _ahora,
      );

      final para = event.para;
      if (para != null && dependientes.any((d) => d.uid == para)) {
        siguiente = siguiente.copiarCon(para: para);
      }

      final original = event.reprogramar;
      if (original != null) {
        if (!medicos.any((m) => m.uid == original.doctorId)) {
          emit(
            siguiente.copiarCon(
              original: original,
              error:
                  'El médico de esta cita ya no aparece en el portal. '
                  'Puedes cancelarla y agendar con otro médico.',
            ),
          );
          return;
        }

        siguiente = siguiente.copiarCon(
          original: original,
          medicoId: original.doctorId,
          tipo: original.tipo,
          fecha: inicioDelDia(original.inicio),
        );
      }

      emit(siguiente.copiarCon(paso: siguiente.primerPaso));

      if (original != null) await _cargarOcupados(emit);
    } catch (error) {
      emit(
        state.copiarCon(
          cargando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos cargar los médicos. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// Los dependientes del titular. Sin ellos se puede agendar igual, para
  /// uno mismo: un fallo aquí no detiene nada.
  Future<List<Dependiente>> _listarDependientes() async {
    try {
      return (await _dependientes.listar(_uid)).lista;
    } catch (_) {
      return const [];
    }
  }

  // ── Elecciones ─────────────────────────────────────────────────────

  void _alElegirPara(AgendarParaElegido event, Emitter<AgendarState> emit) {
    emit(state.copiarCon(para: event.para, ahora: _ahora));
  }

  void _alFiltrar(AgendarFiltrosCambiados event, Emitter<AgendarState> emit) {
    emit(
      state.copiarCon(
        filtroEspecialidad: event.especialidad,
        filtroCiudad: event.ciudad,
        filtroModalidad: event.modalidad,
        limpiarFiltroModalidad: event.quitarModalidad,
        ahora: _ahora,
      ),
    );
  }

  Future<void> _alElegirMedico(
    AgendarMedicoElegido event,
    Emitter<AgendarState> emit,
  ) async {
    if (state.reprogramando) return;

    final medico = state.medicos.where((m) => m.uid == event.uid).firstOrNull;
    if (medico == null) return;

    final ahora = _ahora;
    final modalidades = medico.modalidadesOfrecidas;

    // La modalidad del filtro, si el médico la ofrece; si no, la actual si
    // la ofrece; si no, la primera que tenga.
    final preferida = state.filtroModalidad ?? state.tipo;
    final tipo = modalidades.contains(preferida)
        ? preferida
        : modalidades.first;

    // Arranca en el primer día con atención: hoy solo si aún cabe una cita.
    final fecha = primerDiaConAtencion(
      medico,
      duracionDe(medico, tipo, state.reglas),
      ahora,
      state.reglas,
    );

    emit(
      state.copiarCon(
        medicoId: medico.uid,
        tipo: tipo,
        fecha: fecha,
        limpiarFecha: fecha == null,
        limpiarHueco: true,
        ocupados: const [],
        limpiarErrorOcupados: true,
        limpiarAviso: true,
        paso: PasoAgendar.modalidad,
        ahora: ahora,
      ),
    );

    await _cargarOcupados(emit);
  }

  Future<void> _alElegirModalidad(
    AgendarModalidadElegida event,
    Emitter<AgendarState> emit,
  ) async {
    final medico = state.medico;
    if (state.reprogramando || medico == null) return;
    if (!medico.modalidadesOfrecidas.contains(event.tipo)) return;

    final ahora = _ahora;
    final primero = primerDiaConAtencion(
      medico,
      duracionDe(medico, event.tipo, state.reglas),
      ahora,
      state.reglas,
    );

    // Con otra duración, hoy puede dejar de caber: se corre al primer día.
    final actual = state.fecha;
    final fecha = actual == null || primero == null || actual.isBefore(primero)
        ? primero
        : actual;

    final cambioDeDia = fecha != actual;

    emit(
      state.copiarCon(
        tipo: event.tipo,
        fecha: fecha,
        limpiarFecha: fecha == null,
        limpiarHueco: true,
        limpiarAviso: true,
        paso: PasoAgendar.horario,
        ahora: ahora,
      ),
    );

    if (cambioDeDia || state.ocupados.isEmpty) await _cargarOcupados(emit);
  }

  Future<void> _alElegirFecha(
    AgendarFechaElegida event,
    Emitter<AgendarState> emit,
  ) async {
    final fecha = inicioDelDia(event.fecha);
    final ahora = _ahora;

    if (fecha.isBefore(inicioDelDia(ahora))) return;
    if (state.fecha != null && mismoDia(state.fecha!, fecha)) return;

    emit(
      state.copiarCon(
        fecha: fecha,
        limpiarHueco: true,
        limpiarAviso: true,
        ahora: ahora,
      ),
    );

    await _cargarOcupados(emit);
  }

  void _alElegirHueco(AgendarHuecoElegido event, Emitter<AgendarState> emit) {
    if (event.hueco.ocupado) return;

    emit(
      state.copiarCon(
        hueco: event.hueco,
        limpiarAviso: true,
        limpiarErrorGuardar: true,
        ahora: _ahora,
      ),
    );
  }

  void _alCambiarMotivo(
    AgendarMotivoCambiado event,
    Emitter<AgendarState> emit,
  ) {
    final motivo = event.motivo.length > maximoMotivo
        ? event.motivo.substring(0, maximoMotivo)
        : event.motivo;

    emit(state.copiarCon(motivo: motivo));
  }

  // ── Navegación ─────────────────────────────────────────────────────

  /// Si se puede salir del paso actual hacia adelante.
  static bool pasoCompleto(AgendarState s) {
    return switch (s.paso) {
      PasoAgendar.paciente => true,
      PasoAgendar.filtros => true,
      PasoAgendar.medico => s.medico != null,
      PasoAgendar.modalidad => s.medico != null,
      PasoAgendar.horario => s.huecoValido != null,
      PasoAgendar.motivo => s.motivoValido,
      PasoAgendar.resumen => s.listo,
      PasoAgendar.listo => false,
    };
  }

  static PasoAgendar? pasoSiguiente(AgendarState s) {
    return switch (s.paso) {
      PasoAgendar.paciente => PasoAgendar.filtros,
      PasoAgendar.filtros => PasoAgendar.medico,
      PasoAgendar.medico => PasoAgendar.modalidad,
      PasoAgendar.modalidad => PasoAgendar.horario,
      PasoAgendar.horario =>
        s.reprogramando ? PasoAgendar.resumen : PasoAgendar.motivo,
      PasoAgendar.motivo => PasoAgendar.resumen,
      PasoAgendar.resumen => null,
      PasoAgendar.listo => null,
    };
  }

  /// El paso anterior, o `null` si este es el primero del recorrido.
  static PasoAgendar? pasoAnterior(AgendarState s) {
    if (s.paso == s.primerPaso) return null;

    return switch (s.paso) {
      PasoAgendar.paciente => null,
      PasoAgendar.filtros => s.puedeDependientes ? PasoAgendar.paciente : null,
      PasoAgendar.medico => PasoAgendar.filtros,
      PasoAgendar.modalidad => PasoAgendar.medico,
      PasoAgendar.horario => s.reprogramando ? null : PasoAgendar.modalidad,
      PasoAgendar.motivo => PasoAgendar.horario,
      PasoAgendar.resumen =>
        s.reprogramando ? PasoAgendar.horario : PasoAgendar.motivo,
      PasoAgendar.listo => null,
    };
  }

  void _alContinuar(AgendarContinuado event, Emitter<AgendarState> emit) {
    final siguiente = pasoSiguiente(state);
    if (siguiente == null || !pasoCompleto(state)) return;

    emit(state.copiarCon(paso: siguiente, limpiarAviso: true, ahora: _ahora));
  }

  void _alRetroceder(AgendarRetrocedido event, Emitter<AgendarState> emit) {
    final anterior = pasoAnterior(state);
    if (anterior == null) return;

    emit(
      state.copiarCon(
        paso: anterior,
        limpiarAviso: true,
        limpiarErrorGuardar: true,
        ahora: _ahora,
      ),
    );
  }

  void _alCambiarPaso(AgendarPasoCambiado event, Emitter<AgendarState> emit) {
    // Solo hacia atrás o al mismo: hacia adelante se va con «Continuar»,
    // que comprueba que el paso esté completo.
    if (event.paso.index > state.paso.index) return;
    if (event.paso.index < state.primerPaso.index) return;

    emit(state.copiarCon(paso: event.paso, limpiarAviso: true, ahora: _ahora));
  }

  // ── Lo ocupado ─────────────────────────────────────────────────────

  Future<void> _cargarOcupados(Emitter<AgendarState> emit) async {
    final medico = state.medico;
    final fecha = state.fecha;

    if (medico == null || fecha == null) {
      emit(state.copiarCon(ocupados: const [], cargandoOcupados: false));
      return;
    }

    emit(
      state.copiarCon(
        ocupados: const [],
        cargandoOcupados: true,
        limpiarErrorOcupados: true,
      ),
    );

    try {
      final ocupados = await _portal.ocupados(medico.uid, fecha, fecha);

      // Descarta respuestas viejas si ya se cambió de día o de médico.
      if (state.medicoId != medico.uid || state.fecha != fecha) return;

      emit(
        state.copiarCon(
          ocupados: ocupados,
          cargandoOcupados: false,
          ahora: _ahora,
        ),
      );
    } catch (error) {
      if (state.medicoId != medico.uid || state.fecha != fecha) return;

      emit(
        state.copiarCon(
          cargandoOcupados: false,
          errorOcupados: mensajeDeError(
            error,
            generico: 'No pudimos ver los horarios ocupados de ese día.',
          ),
        ),
      );
    }
  }

  // ── Confirmar ──────────────────────────────────────────────────────

  Future<void> _alConfirmar(
    AgendarConfirmado event,
    Emitter<AgendarState> emit,
  ) async {
    final actual = state.copiarCon(ahora: _ahora);
    final hueco = actual.huecoValido;
    final medico = actual.medico;

    if (hueco == null || medico == null || !actual.listo) {
      // Pudo vencerse mientras la persona leía el resumen.
      if (hueco == null && actual.hueco != null) {
        emit(
          actual.copiarCon(
            paso: PasoAgendar.horario,
            limpiarHueco: true,
            aviso: 'Ese horario ya no está disponible. Elige otro.',
          ),
        );
      }
      return;
    }

    emit(actual.copiarCon(guardando: true, limpiarErrorGuardar: true));

    try {
      final original = actual.original;
      final Cita cita = original != null
          ? await _portal.reprogramar(original.id, hueco.inicio, hueco.fin)
          : await _portal.agendar(
              NuevaCita(
                doctorId: medico.uid,
                inicio: hueco.inicio,
                fin: hueco.fin,
                tipo: actual.tipo,
                motivo: actual.motivoLimpio,
                pacienteId: actual.para == paraMi ? null : actual.para,
              ),
            );

      // La respuesta de reprogramar no trae el nombre del médico: se
      // completa con lo que ya se sabe, para enseñarlo y guardarlo bien.
      final completa = cita.copiarCon(
        medico: cita.medico ?? medico.nombre,
        especialidad: cita.especialidad ?? medico.especialidad,
        pacienteNombre:
            cita.pacienteNombre ??
            original?.pacienteNombre ??
            actual.pacienteNombre,
        paraDependiente: original?.paraDependiente ?? actual.para != paraMi,
      );

      emit(
        state.copiarCon(
          guardando: false,
          agendada: completa,
          paso: PasoAgendar.listo,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          guardando: false,
          errorGuardar: mensajeDeError(
            error,
            generico: actual.reprogramando
                ? 'No se pudo reprogramar la cita.'
                : 'No se pudo agendar la cita.',
          ),
        ),
      );

      // Quizá alguien tomó ese horario mientras tanto: se refresca lo
      // ocupado y, si el elegido ya no está libre, se vuelve a elegir.
      await _cargarOcupados(emit);

      if (state.hueco != null && state.huecoValido == null) {
        emit(
          state.copiarCon(
            paso: PasoAgendar.horario,
            limpiarHueco: true,
            aviso: avisoHorarioTomado,
          ),
        );
      }
    }
  }

  // ── Dependientes y reinicio ────────────────────────────────────────

  Future<void> _alRecargarDependientes(
    AgendarDependientesRecargados event,
    Emitter<AgendarState> emit,
  ) async {
    final dependientes = await _listarDependientes();
    final elegir = event.elegir;

    emit(
      state.copiarCon(
        dependientes: dependientes.isEmpty ? state.dependientes : dependientes,
        para: elegir != null && dependientes.any((d) => d.uid == elegir)
            ? elegir
            : null,
      ),
    );
  }

  void _alEmpezarOtra(AgendarOtraCita event, Emitter<AgendarState> emit) {
    emit(
      AgendarState(
        ahora: _ahora,
        reglas: state.reglas,
        cargando: false,
        medicos: state.medicos,
        especialidades: state.especialidades,
        catalogoCiudades: state.catalogoCiudades,
        dependientes: state.dependientes,
        puedeDependientes: state.puedeDependientes,
        nombreTitular: state.nombreTitular,
        paso: state.puedeDependientes
            ? PasoAgendar.paciente
            : PasoAgendar.filtros,
      ),
    );
  }
}
