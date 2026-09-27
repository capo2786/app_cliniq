import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../../core/network/errores.dart';
import '../../citas/data/models/cita.dart';
import '../../dependientes/data/dependientes_service.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/models/medico_portal.dart';
import '../data/portal_service.dart';
import '../dominio/huecos.dart';
import 'agendar_event.dart';
import 'agendar_state.dart';

const String avisoHorarioTomado =
    'Ese horario acaba de ocuparse. Elige otro de la lista actualizada.';

/// El agendamiento paso a paso: para quién, qué especialidad, qué médico,
/// qué modalidad, qué día y hora, el motivo, y confirmar.
///
/// La pantalla lo crea en cada visita —como las salas en UCEBell— para que
/// los turnos lleguen frescos cada vez. Qué turnos se pueden tomar lo decide
/// la API (`/portal/proximos-turnos` y `/portal/turnos/:doctorId`); aquí solo
/// se decide cuándo se piden los datos y a qué paso se va. Sin red no se
/// inventa nada: se dice que no se pudo y se ofrece reintentar.
class AgendarBloc extends Bloc<AgendarEvent, AgendarState> {
  final PortalService _portal;
  final DependientesService _dependientes;
  final RelojClinica _reloj;
  final String _uid;

  /// [reglas] son las de la configuración de la clínica; [ciudades], el
  /// catálogo que ordena el filtro de ciudad. Las especialidades ya llegan
  /// ordenadas de la API.
  AgendarBloc({
    required this._portal,
    required this._dependientes,
    required this._uid,
    required String nombreTitular,
    required ReglasAgendamiento reglas,
    List<String> ciudades = const [],
    bool puedeDependientes = true,
    RelojClinica? reloj,
  }) : _reloj = reloj ?? RelojClinica(),
       super(
         AgendarState(
           ahora: (reloj ?? RelojClinica()).ahora(),
           reglas: reglas,
           catalogoCiudades: ciudades,
           nombreTitular: nombreTitular,
           puedeDependientes: puedeDependientes,
         ),
       ) {
    on<AgendarIniciado>(_alIniciar);
    on<AgendarParaElegido>(_alElegirPara);
    on<AgendarFiltrosCambiados>(_alFiltrar);
    on<AgendarEspecialidadElegida>(_alElegirEspecialidad);
    on<AgendarBusquedaCambiada>(_alBuscar);
    on<AgendarMedicoElegido>(_alElegirMedico);
    on<AgendarPrimerTurnoElegido>(_alElegirPrimerTurno);
    on<AgendarModalidadElegida>(_alElegirModalidad);
    on<AgendarFechaElegida>(_alElegirFecha);
    on<AgendarHuecoElegido>(_alElegirHueco);
    on<AgendarMotivoCambiado>(_alCambiarMotivo);
    on<AgendarPasoCambiado>(_alCambiarPaso);
    on<AgendarContinuado>(_alContinuar);
    on<AgendarRetrocedido>(_alRetroceder);
    on<AgendarConfirmado>(_alConfirmar);
    on<AgendarTurnosReintentados>((event, emit) => _cargarTurnos(emit));
    on<AgendarProximosReintentados>((event, emit) => _cargarProximos(emit));
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

    final original = event.reprogramar;
    if (original != null) return _iniciarReprogramacion(original, emit);

    try {
      final proximos = await _portal.proximosTurnos(
        ciudad: state.filtroCiudad,
        modalidad: state.filtroModalidad,
      );

      final dependientes = state.puedeDependientes
          ? await _listarDependientes()
          : state.dependientes;

      var siguiente = state.copiarCon(
        cargando: false,
        medicos: proximos.medicos,
        especialidades: proximos.especialidades,
        ciudades: AgendarState.ordenarCiudades(
          state.catalogoCiudades,
          proximos.medicos,
        ),
        limpiarErrorProximos: true,
        dependientes: dependientes,
        ahora: _ahora,
      );

      final para = event.para;
      if (para != null && dependientes.any((d) => d.uid == para)) {
        siguiente = siguiente.copiarCon(para: para);
      }

      emit(siguiente.copiarCon(paso: siguiente.primerPaso));
    } catch (error) {
      emit(
        state.copiarCon(
          cargando: false,
          error: mensajeDeError(
            error,
            generico:
                'No pudimos cargar los médicos disponibles. Intenta de '
                'nuevo.',
          ),
        ),
      );
    }
  }

  /// Reprogramar: el mismo médico y la misma modalidad, directo a la hora.
  ///
  /// El médico sale de la propia cita; sus turnos, de la API. Si la API dice
  /// que el médico ya no atiende por el portal o no ofrece la modalidad
  /// (404/409, con el mismo mensaje que daría la reserva), no hay a dónde
  /// moverla.
  Future<void> _iniciarReprogramacion(
    Cita original,
    Emitter<AgendarState> emit,
  ) async {
    final medico = MedicoPortal(
      uid: original.doctorId,
      nombre: original.medicoVisible ?? '',
      especialidad: original.especialidad,
      modalidades: [original.tipo],
    );

    emit(
      state.copiarCon(
        cargando: false,
        original: original,
        medico: medico,
        tipo: original.tipo,
        fecha: inicioDelDia(original.inicio),
        paso: PasoAgendar.horario,
        ahora: _ahora,
      ),
    );

    final error = await _cargarTurnos(emit);
    final estado = error == null ? null : estadoDe(error);

    if (estado == 404 || estado == 409) {
      final motivo =
          mensajeDelServidor(error!) ??
          'El médico de esta cita ya no aparece en el portal.';

      emit(
        state.copiarCon(
          error: '$motivo Puedes cancelarla y agendar con otro médico.',
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

  Future<void> _alFiltrar(
    AgendarFiltrosCambiados event,
    Emitter<AgendarState> emit,
  ) async {
    final antes = state;

    emit(
      state.copiarCon(
        filtroCiudad: event.ciudad,
        filtroModalidad: event.modalidad,
        limpiarFiltroModalidad: event.quitarModalidad,
        ahora: _ahora,
      ),
    );

    if (state.filtroCiudad != antes.filtroCiudad ||
        state.filtroModalidad != antes.filtroModalidad) {
      await _cargarProximos(emit);
    }
  }

  void _alElegirEspecialidad(
    AgendarEspecialidadElegida event,
    Emitter<AgendarState> emit,
  ) {
    if (state.reprogramando) return;

    emit(
      state.copiarCon(
        filtroEspecialidad: event.especialidad.trim(),
        busqueda: '',
        paso: PasoAgendar.medico,
        limpiarAviso: true,
        ahora: _ahora,
      ),
    );
  }

  void _alBuscar(AgendarBusquedaCambiada event, Emitter<AgendarState> emit) {
    emit(state.copiarCon(busqueda: event.texto));
  }

  Future<void> _alElegirMedico(
    AgendarMedicoElegido event,
    Emitter<AgendarState> emit,
  ) async {
    if (state.reprogramando) return;

    final medico = state.medicos.where((m) => m.uid == event.uid).firstOrNull;
    if (medico == null) return;

    final modalidades = medico.modalidadesOfrecidas;

    // La modalidad del filtro, si el médico la ofrece; si no, la de su
    // próximo turno; si no, la actual si la ofrece; si no, la primera.
    final preferida =
        state.filtroModalidad ?? medico.proximo?.modalidad ?? state.tipo;
    final tipo = modalidades.contains(preferida)
        ? preferida
        : modalidades.first;

    emit(
      state.copiarCon(
        medico: medico,
        tipo: tipo,
        limpiarFecha: true,
        limpiarHueco: true,
        limpiarTurnos: true,
        limpiarErrorTurnos: true,
        limpiarAviso: true,
        paso: PasoAgendar.modalidad,
        ahora: _ahora,
      ),
    );

    await _cargarTurnos(emit);
  }

  /// «El primer turno disponible»: se eligen el médico, la modalidad y el
  /// turno de una vez, y se confirma contra los turnos de la API antes de
  /// seguir. Si entretanto el turno se ocupó, se va a la rejilla con la
  /// lista actualizada.
  Future<void> _alElegirPrimerTurno(
    AgendarPrimerTurnoElegido event,
    Emitter<AgendarState> emit,
  ) async {
    if (state.reprogramando) return;

    final turno = event.turno;
    final medico = state.medicos
        .where((m) => m.uid == turno.doctorId)
        .firstOrNull;
    if (medico == null) return;
    if (!medico.modalidadesOfrecidas.contains(turno.modalidad)) return;

    emit(
      state.copiarCon(
        medico: medico,
        tipo: turno.modalidad,
        fecha: inicioDelDia(turno.inicio),
        hueco: Hueco.deTurno(turno.turno, state.reglas),
        limpiarTurnos: true,
        limpiarErrorTurnos: true,
        limpiarAviso: true,
        ahora: _ahora,
      ),
    );

    await _cargarTurnos(emit);

    // Mientras tanto se eligió otra cosa: esa elección manda.
    if (state.medicoId != medico.uid || state.tipo != turno.modalidad) return;

    if (state.huecoValido != null) {
      emit(state.copiarCon(paso: PasoAgendar.motivo));
      return;
    }

    emit(
      state.copiarCon(
        paso: PasoAgendar.horario,
        limpiarHueco: true,
        aviso: state.errorTurnos == null ? avisoHorarioTomado : null,
      ),
    );
  }

  Future<void> _alElegirModalidad(
    AgendarModalidadElegida event,
    Emitter<AgendarState> emit,
  ) async {
    final medico = state.medico;
    if (state.reprogramando || medico == null) return;
    if (!medico.modalidadesOfrecidas.contains(event.tipo)) return;

    final otra = event.tipo != state.tipo;

    emit(
      state.copiarCon(
        tipo: event.tipo,
        limpiarHueco: true,
        limpiarAviso: true,
        paso: PasoAgendar.horario,
        ahora: _ahora,
      ),
    );

    // Con otra modalidad cambian la duración y los turnos: se piden de nuevo.
    if (otra || (state.turnosActuales == null && !state.cargandoTurnos)) {
      await _cargarTurnos(emit);
    }
  }

  void _alElegirFecha(AgendarFechaElegida event, Emitter<AgendarState> emit) {
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
  }

  void _alElegirHueco(AgendarHuecoElegido event, Emitter<AgendarState> emit) {
    // Solo los que se están ofreciendo.
    final actual = state.copiarCon(ahora: _ahora);
    if (!actual.huecos.any(event.hueco.mismoHorario)) return;

    emit(
      actual.copiarCon(
        hueco: event.hueco,
        limpiarAviso: true,
        limpiarErrorGuardar: true,
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
    final actual = state.copiarCon(ahora: _ahora);
    final siguiente = pasoSiguiente(actual);
    if (siguiente == null || !pasoCompleto(actual)) return;

    emit(actual.copiarCon(paso: siguiente, limpiarAviso: true));
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

  // ── Lo que se pide a la API ────────────────────────────────────────

  /// `GET /portal/proximos-turnos` con los filtros de ciudad y modalidad.
  ///
  /// Sin red, la lista queda vacía con el error y la opción de reintentar:
  /// una lista vieja con otros filtros diría médicos y horas que no son.
  /// Devuelve el error, si lo hubo.
  Future<Object?> _cargarProximos(Emitter<AgendarState> emit) async {
    final ciudad = state.filtroCiudad;
    final modalidad = state.filtroModalidad;

    bool vieja() =>
        state.filtroCiudad != ciudad || state.filtroModalidad != modalidad;

    emit(state.copiarCon(cargandoProximos: true, limpiarErrorProximos: true));

    try {
      final proximos = await _portal.proximosTurnos(
        ciudad: ciudad,
        modalidad: modalidad,
      );
      if (vieja()) return null;

      emit(
        state.copiarCon(
          cargandoProximos: false,
          medicos: proximos.medicos,
          especialidades: proximos.especialidades,
          // Con una ciudad elegida la lista solo trae esa: se conservan las
          // opciones que había para poder cambiarla.
          ciudades: ciudad.isEmpty
              ? AgendarState.ordenarCiudades(
                  state.catalogoCiudades,
                  proximos.medicos,
                )
              : null,
          ahora: _ahora,
        ),
      );
      return null;
    } catch (error) {
      if (vieja()) return null;

      emit(
        state.copiarCon(
          cargandoProximos: false,
          medicos: const [],
          especialidades: const [],
          errorProximos: mensajeDeError(
            error,
            generico: 'No pudimos ver los turnos disponibles.',
          ),
        ),
      );
      return error;
    }
  }

  /// `GET /portal/turnos/:doctorId` del médico y la modalidad elegidos, de
  /// hoy al horizonte de la clínica. Al reprogramar se excluye la cita que
  /// se mueve, para que su horario y los de al lado se ofrezcan.
  ///
  /// Si el día elegido se quedó sin turnos, se pasa al primero que tenga.
  /// Devuelve el error, si lo hubo.
  Future<Object?> _cargarTurnos(Emitter<AgendarState> emit) async {
    final medico = state.medico;
    final tipo = state.tipo;

    if (medico == null) {
      emit(state.copiarCon(limpiarTurnos: true, cargandoTurnos: false));
      return null;
    }

    bool vieja() => state.medicoId != medico.uid || state.tipo != tipo;

    emit(state.copiarCon(cargandoTurnos: true, limpiarErrorTurnos: true));

    try {
      final turnos = await _portal.turnos(
        medico.uid,
        tipo,
        excluirCita: state.original?.id,
      );
      if (vieja()) return null;

      var siguiente = state.copiarCon(
        turnos: turnos,
        cargandoTurnos: false,
        ahora: _ahora,
      );

      final fecha = siguiente.fecha;
      if (fecha == null || !siguiente.tieneTurnos(fecha)) {
        final primero = siguiente.primerDia;
        siguiente = siguiente.copiarCon(
          fecha: primero,
          limpiarFecha: primero == null,
        );
      }

      emit(siguiente);
      return null;
    } catch (error) {
      if (vieja()) return null;

      emit(
        state.copiarCon(
          cargandoTurnos: false,
          limpiarTurnos: true,
          errorTurnos: mensajeDeError(
            error,
            generico: 'No pudimos ver los turnos libres de este médico.',
          ),
        ),
      );
      return error;
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
        medico: cita.medico ?? (medico.nombre.isEmpty ? null : medico.nombre),
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
      await _alFallarGuardado(error, actual, hueco, emit);
    }
  }

  /// Agendar o reprogramar falló.
  ///
  /// Con 409 el turno se tomó entretanto (o por otra razón ya no se puede):
  /// se enseña el mensaje del servidor, se vuelven a pedir los turnos del
  /// médico y, al agendar, los próximos turnos, y se vuelve a la rejilla sin
  /// ese turno. Lo demás que eligió la persona —para quién, especialidad,
  /// médico, modalidad y motivo— se conserva.
  ///
  /// Sin red no hay nada que recargar: se queda en el resumen con el
  /// mensaje. Con otro error del servidor se recargan los turnos y solo se
  /// vuelve a la rejilla si el elegido ya no está.
  Future<void> _alFallarGuardado(
    Object error,
    AgendarState actual,
    Hueco hueco,
    Emitter<AgendarState> emit,
  ) async {
    final tomado = estadoDe(error) == 409;
    final medicoId = actual.medicoId ?? '';
    final mensaje = tomado
        ? mensajeDelServidor(error) ?? avisoHorarioTomado
        : mensajeDeError(
            error,
            generico: actual.reprogramando
                ? 'No se pudo reprogramar la cita.'
                : 'No se pudo agendar la cita.',
          );

    emit(
      state.copiarCon(
        guardando: false,
        errorGuardar: mensaje,
        descartados: tomado
            ? {
                ...state.descartados,
                AgendarState.claveDescartado(medicoId, hueco.inicio),
              }
            : null,
      ),
    );

    if (esFaltaDeRed(error)) return;

    await Future.wait([
      _cargarTurnos(emit),
      if (tomado && !actual.reprogramando) _cargarProximos(emit),
    ]);

    if (tomado) {
      emit(
        state.copiarCon(
          paso: PasoAgendar.horario,
          limpiarHueco: true,
          aviso: mensaje,
        ),
      );
      return;
    }

    if (state.hueco != null &&
        state.errorTurnos == null &&
        state.huecoValido == null) {
      emit(
        state.copiarCon(
          paso: PasoAgendar.horario,
          limpiarHueco: true,
          aviso: avisoHorarioTomado,
        ),
      );
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

  /// Después del éxito: otra cita desde cero. Los próximos turnos se piden
  /// de nuevo, porque el que se acaba de tomar ya no está libre.
  Future<void> _alEmpezarOtra(
    AgendarOtraCita event,
    Emitter<AgendarState> emit,
  ) async {
    emit(
      AgendarState(
        ahora: _ahora,
        reglas: state.reglas,
        cargando: false,
        medicos: state.medicos,
        especialidades: state.especialidades,
        catalogoCiudades: state.catalogoCiudades,
        ciudades: state.ciudades,
        dependientes: state.dependientes,
        puedeDependientes: state.puedeDependientes,
        nombreTitular: state.nombreTitular,
        descartados: state.descartados,
        paso: state.puedeDependientes
            ? PasoAgendar.paciente
            : PasoAgendar.filtros,
      ),
    );

    await _cargarProximos(emit);
  }
}
