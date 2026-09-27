import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/network/errores.dart';
import '../../dependientes/data/dependientes_service.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/consultas_service.dart';
import '../data/models/campo_formulario.dart';
import '../data/models/consulta.dart';
import '../data/models/opciones_consulta.dart';
import '../dominio/reglas_consultas.dart';
import 'consultas_state.dart';
import 'nueva_consulta_event.dart';
import 'nueva_consulta_state.dart';

/// Una consulta en línea nueva, paso a paso: para quién, la especialidad, el
/// motivo, el médico, el formulario del motivo con la descripción y los
/// archivos, el resumen y el envío.
///
/// Enviar son tres llamadas: se crea (o se pone al día) el borrador, se suben
/// los archivos uno por uno y se envía. Si algo falla a mitad, lo ya hecho
/// queda en el borrador y reintentar sigue desde ahí: no se vuelve a crear
/// otra consulta ni a subir lo que ya subió.
///
/// La pantalla lo crea en cada visita, como el agendamiento: las opciones
/// (especialidades, motivos y médicos) tienen que llegar frescas.
class NuevaConsultaBloc extends Bloc<NuevaConsultaEvent, NuevaConsultaState> {
  final ConsultasService _consultas;
  final DependientesService _dependientes;
  final String _uid;

  int _secuencia = 0;

  NuevaConsultaBloc({
    required this._consultas,
    required this._dependientes,
    required this._uid,
    required String nombreTitular,
    bool puedeDependientes = true,
  }) : super(
         NuevaConsultaState(
           nombreTitular: nombreTitular,
           puedeDependientes: puedeDependientes,
         ),
       ) {
    on<NuevaConsultaIniciada>(_alIniciar);
    on<NuevaConsultaParaElegido>(_alElegirPara);
    on<NuevaConsultaEspecialidadElegida>(_alElegirEspecialidad);
    on<NuevaConsultaMotivoElegido>(_alElegirMotivo);
    on<NuevaConsultaMedicoElegido>(_alElegirMedico);
    on<NuevaConsultaRespuestaCambiada>(_alResponder);
    on<NuevaConsultaDescripcionCambiada>(_alDescribir);
    on<NuevaConsultaArchivosElegidos>(_alElegirArchivos);
    on<NuevaConsultaAdjuntoQuitado>(_alQuitarAdjunto);
    on<NuevaConsultaContinuada>(_alContinuar);
    on<NuevaConsultaRetrocedida>(_alRetroceder);
    on<NuevaConsultaPasoCambiado>(_alCambiarPaso);
    on<NuevaConsultaBorradorGuardado>(
      (event, emit) => _guardar(emit, enviar: false),
    );
    on<NuevaConsultaConfirmada>((event, emit) => _guardar(emit, enviar: true));
    on<NuevaConsultaDescartada>(_alDescartar);
    on<NuevaConsultaDependientesRecargados>(_alRecargarDependientes);
  }

  AvisoConsultas _aviso(String mensaje, {bool exito = false}) =>
      AvisoConsultas(exito: exito, mensaje: mensaje, secuencia: ++_secuencia);

  // ── Carga inicial ──────────────────────────────────────────────────

  Future<void> _alIniciar(
    NuevaConsultaIniciada event,
    Emitter<NuevaConsultaState> emit,
  ) async {
    emit(state.copiarCon(cargando: true, limpiarError: true));

    try {
      final especialidades = await _consultas.opciones();
      final dependientes = state.puedeDependientes
          ? await _listarDependientes()
          : state.dependientes;

      var siguiente = state.copiarCon(
        cargando: false,
        especialidades: especialidades,
        dependientes: dependientes,
      );

      final para = event.para;
      if (para != null && dependientes.any((d) => d.uid == para)) {
        siguiente = siguiente.copiarCon(para: para);
      }

      final borradorId = event.borradorId;
      if (borradorId != null) {
        final detalle = (await _consultas.detalle(_uid, borradorId)).detalle;

        if (detalle.estado != EstadoConsulta.borrador) {
          emit(
            siguiente.copiarCon(
              error:
                  'Esta consulta ya se envió. Ábrela desde la lista para '
                  'ver cómo va.',
            ),
          );
          return;
        }

        siguiente = _retomar(siguiente, detalle);
      } else if (especialidades.isEmpty) {
        emit(
          siguiente.copiarCon(
            error:
                'Por ahora ningún médico atiende consultas en línea. Agenda '
                'una cita o vuelve a intentarlo más tarde.',
          ),
        );
        return;
      }

      emit(siguiente.copiarCon(paso: siguiente.primerPaso));
    } catch (error) {
      emit(
        state.copiarCon(
          cargando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos preparar la consulta. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// Arma el estado desde un borrador guardado.
  ///
  /// El motivo y el médico se buscan en las opciones para tener su
  /// descripción y si piden un archivo; si ya no están (el motivo se
  /// desactivó), el borrador trae lo suficiente para seguir: el nombre y las
  /// preguntas.
  NuevaConsultaState _retomar(NuevaConsultaState base, ConsultaDetalle d) {
    final especialidad = base.especialidades
        .where((e) => e.nombre == d.especialidad)
        .firstOrNull;

    final motivo =
        _buscarMotivo(base.especialidades, d.motivoId) ??
        MotivoPublico(
          id: d.motivoId,
          nombre: d.motivoNombre.isEmpty ? 'Motivo' : d.motivoNombre,
          especialidad: d.especialidad,
          campos:
              d.campos ??
              [
                for (final r in d.respuestas)
                  CampoFormulario(
                    clave: r.clave,
                    etiqueta: r.etiqueta,
                    tipo: r.tipo,
                  ),
              ],
        );

    final medico =
        especialidad?.medicos.where((m) => m.uid == d.medicoId).firstOrNull ??
        MedicoConsulta(
          uid: d.medicoId,
          nombre: d.medicoNombre,
          especialidad: d.especialidad,
        );

    return base.copiarCon(
      borrador: d,
      para: d.paraDependiente ? d.pacienteId : consultaParaMi,
      especialidad: d.especialidad,
      motivo: motivo,
      medico: medico,
      respuestas: respuestasEditables(d.respuestas),
      descripcion: d.descripcion,
      adjuntos: [for (final a in d.adjuntos) AdjuntoSubido(a)],
    );
  }

  static MotivoPublico? _buscarMotivo(
    List<EspecialidadConsulta> especialidades,
    String id,
  ) {
    for (final e in especialidades) {
      for (final m in e.motivos) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  /// Los dependientes del titular. Sin ellos se puede consultar igual, para
  /// uno mismo: un fallo aquí no detiene nada.
  Future<List<Dependiente>> _listarDependientes() async {
    try {
      return (await _dependientes.listar(_uid)).lista;
    } catch (_) {
      return const [];
    }
  }

  // ── Elecciones ─────────────────────────────────────────────────────

  void _alElegirPara(
    NuevaConsultaParaElegido event,
    Emitter<NuevaConsultaState> emit,
  ) {
    if (state.fijada) return;

    final valido =
        event.para == consultaParaMi ||
        state.dependientes.any((d) => d.uid == event.para);
    if (!valido) return;

    emit(state.copiarCon(para: event.para));
  }

  void _alElegirEspecialidad(
    NuevaConsultaEspecialidadElegida event,
    Emitter<NuevaConsultaState> emit,
  ) {
    if (state.fijada) return;
    if (!state.especialidades.any((e) => e.nombre == event.especialidad)) {
      return;
    }

    // Otra especialidad: otros motivos y otros médicos.
    final cambia = state.especialidad != event.especialidad;

    emit(
      state.copiarCon(
        especialidad: event.especialidad,
        limpiarMotivo: cambia,
        limpiarMedico: cambia,
        respuestas: cambia ? const {} : null,
        mostrarErrores: cambia ? false : null,
        paso: PasoConsulta.motivo,
      ),
    );
  }

  void _alElegirMotivo(
    NuevaConsultaMotivoElegido event,
    Emitter<NuevaConsultaState> emit,
  ) {
    if (state.fijada) return;

    final motivo = state.motivosDisponibles
        .where((m) => m.id == event.motivoId)
        .firstOrNull;
    if (motivo == null) return;

    // Otro motivo, otras preguntas: lo respondido al anterior no sirve.
    final cambia = state.motivo?.id != motivo.id;

    emit(
      state.copiarCon(
        motivo: motivo,
        respuestas: cambia ? const {} : null,
        mostrarErrores: cambia ? false : null,
        paso: PasoConsulta.medico,
      ),
    );
  }

  void _alElegirMedico(
    NuevaConsultaMedicoElegido event,
    Emitter<NuevaConsultaState> emit,
  ) {
    if (state.fijada) return;

    final medico = state.medicosDisponibles
        .where((m) => m.uid == event.uid)
        .firstOrNull;
    if (medico == null) return;

    emit(state.copiarCon(medico: medico, paso: PasoConsulta.formulario));
  }

  void _alResponder(
    NuevaConsultaRespuestaCambiada event,
    Emitter<NuevaConsultaState> emit,
  ) {
    if (!state.campos.any((c) => c.clave == event.clave)) return;

    emit(
      state.copiarCon(
        respuestas: {...state.respuestas, event.clave: event.valor},
      ),
    );
  }

  void _alDescribir(
    NuevaConsultaDescripcionCambiada event,
    Emitter<NuevaConsultaState> emit,
  ) {
    final texto = event.descripcion.length > maximoDescripcion
        ? event.descripcion.substring(0, maximoDescripcion)
        : event.descripcion;

    emit(state.copiarCon(descripcion: texto));
  }

  // ── Archivos ───────────────────────────────────────────────────────

  void _alElegirArchivos(
    NuevaConsultaArchivosElegidos event,
    Emitter<NuevaConsultaState> emit,
  ) {
    final problemas = [...event.seleccion.problemas];
    final nuevos = <AdjuntoConsulta>[];

    for (final archivo in event.seleccion.archivos) {
      final problema = problemaDelArchivo(archivo);

      if (problema != null) {
        problemas.add(problema);
        continue;
      }

      if (state.adjuntos.length + nuevos.length >= maximoAdjuntos) {
        problemas.add('Puedes adjuntar hasta $maximoAdjuntos archivos.');
        break;
      }

      nuevos.add(AdjuntoPendiente(archivo));
    }

    if (nuevos.isEmpty && problemas.isEmpty) return;

    emit(
      state.copiarCon(
        adjuntos: [...state.adjuntos, ...nuevos],
        aviso: problemas.isEmpty ? null : _aviso(problemas.join('\n')),
      ),
    );
  }

  Future<void> _alQuitarAdjunto(
    NuevaConsultaAdjuntoQuitado event,
    Emitter<NuevaConsultaState> emit,
  ) async {
    final adjunto = event.adjunto;

    switch (adjunto) {
      case AdjuntoPendiente():
        final indice = state.adjuntos.indexOf(adjunto);
        if (indice < 0) return;

        emit(state.copiarCon(adjuntos: [...state.adjuntos]..removeAt(indice)));

      case AdjuntoSubido():
        final borrador = state.borrador;
        if (borrador == null || state.quitandoId != null) return;

        emit(state.copiarCon(quitandoId: adjunto.archivo.id));

        try {
          await _consultas.quitarAdjunto(borrador.id, adjunto.archivo.id);

          emit(
            state.copiarCon(
              adjuntos: [
                for (final a in state.adjuntos)
                  if (a != adjunto) a,
              ],
              limpiarQuitando: true,
            ),
          );
        } catch (error) {
          emit(
            state.copiarCon(
              limpiarQuitando: true,
              aviso: _aviso(
                mensajeDeError(
                  error,
                  generico: 'No se pudo quitar el archivo.',
                ),
              ),
            ),
          );
        }
    }
  }

  // ── Navegación ─────────────────────────────────────────────────────

  /// Si se puede salir del paso actual hacia adelante.
  static bool pasoCompleto(NuevaConsultaState s) {
    return switch (s.paso) {
      PasoConsulta.paciente => true,
      PasoConsulta.especialidad => s.especialidadElegida != null,
      PasoConsulta.motivo => s.motivo != null,
      PasoConsulta.medico => s.medico != null,
      PasoConsulta.formulario => s.errores.isEmpty,
      PasoConsulta.resumen => s.lista,
      PasoConsulta.enviada => false,
    };
  }

  static PasoConsulta? pasoSiguiente(NuevaConsultaState s) {
    return switch (s.paso) {
      PasoConsulta.paciente => PasoConsulta.especialidad,
      PasoConsulta.especialidad => PasoConsulta.motivo,
      PasoConsulta.motivo => PasoConsulta.medico,
      PasoConsulta.medico => PasoConsulta.formulario,
      PasoConsulta.formulario => PasoConsulta.resumen,
      PasoConsulta.resumen => null,
      PasoConsulta.enviada => null,
    };
  }

  /// El paso anterior, o `null` si este es el primero del recorrido.
  static PasoConsulta? pasoAnterior(NuevaConsultaState s) {
    if (s.paso == s.primerPaso || s.paso == PasoConsulta.enviada) return null;

    return switch (s.paso) {
      PasoConsulta.paciente => null,
      PasoConsulta.especialidad =>
        s.puedeDependientes ? PasoConsulta.paciente : null,
      PasoConsulta.motivo => PasoConsulta.especialidad,
      PasoConsulta.medico => PasoConsulta.motivo,
      PasoConsulta.formulario => PasoConsulta.medico,
      PasoConsulta.resumen => PasoConsulta.formulario,
      PasoConsulta.enviada => null,
    };
  }

  void _alContinuar(
    NuevaConsultaContinuada event,
    Emitter<NuevaConsultaState> emit,
  ) {
    final siguiente = pasoSiguiente(state);
    if (siguiente == null) return;

    if (!pasoCompleto(state)) {
      // En el formulario, intentar seguir marca lo que falta.
      if (state.paso == PasoConsulta.formulario) {
        emit(state.copiarCon(mostrarErrores: true));
      }
      return;
    }

    emit(state.copiarCon(paso: siguiente, limpiarErrorGuardar: true));
  }

  void _alRetroceder(
    NuevaConsultaRetrocedida event,
    Emitter<NuevaConsultaState> emit,
  ) {
    final anterior = pasoAnterior(state);
    if (anterior == null || state.guardando) return;

    emit(state.copiarCon(paso: anterior, limpiarErrorGuardar: true));
  }

  void _alCambiarPaso(
    NuevaConsultaPasoCambiado event,
    Emitter<NuevaConsultaState> emit,
  ) {
    // Solo hacia atrás: hacia adelante se va con «Continuar», que comprueba
    // que el paso esté completo.
    if (state.guardando || state.paso == PasoConsulta.enviada) return;
    if (event.paso.index >= state.paso.index) return;
    if (event.paso.index < state.primerPaso.index) return;

    emit(state.copiarCon(paso: event.paso, limpiarErrorGuardar: true));
  }

  // ── Guardar y enviar ───────────────────────────────────────────────

  Future<void> _guardar(
    Emitter<NuevaConsultaState> emit, {
    required bool enviar,
  }) async {
    final motivo = state.motivo;
    final medico = state.medico;
    if (state.guardando || motivo == null || medico == null) return;

    if (enviar && state.errores.isNotEmpty) {
      emit(
        state.copiarCon(paso: PasoConsulta.formulario, mostrarErrores: true),
      );
      return;
    }

    emit(
      state.copiarCon(
        guardando: true,
        limpiarErrorGuardar: true,
        progreso: 'Guardando tu consulta…',
      ),
    );

    try {
      final respuestas = respuestasParaApi(state.campos, state.respuestas);
      final previo = state.borrador;

      final borrador = previo == null
          ? await _consultas.crear(
              NuevaConsulta(
                motivoId: motivo.id,
                medicoId: medico.uid,
                pacienteId: state.para == consultaParaMi ? null : state.para,
                respuestas: respuestas,
                descripcion: state.descripcionLimpia,
              ),
            )
          : await _consultas.actualizar(
              previo.id,
              respuestas: respuestas,
              descripcion: state.descripcionLimpia,
            );

      emit(state.copiarCon(borrador: borrador));

      // Los archivos, uno por uno: cada uno que sube queda marcado, así un
      // corte a mitad no obliga a subirlos todos otra vez.
      final pendientes = state.adjuntos.whereType<AdjuntoPendiente>().toList();

      for (var i = 0; i < pendientes.length; i++) {
        emit(
          state.copiarCon(
            progreso: pendientes.length == 1
                ? 'Subiendo el archivo…'
                : 'Subiendo archivo ${i + 1} de ${pendientes.length}…',
          ),
        );

        final meta = await _consultas.subirAdjunto(
          borrador.id,
          pendientes[i].archivo,
        );

        final adjuntos = [...state.adjuntos];
        final indice = adjuntos.indexOf(pendientes[i]);
        if (indice >= 0) adjuntos[indice] = AdjuntoSubido(meta);

        emit(state.copiarCon(adjuntos: adjuntos));
      }

      if (!enviar) {
        emit(
          state.copiarCon(
            guardando: false,
            limpiarProgreso: true,
            aviso: _aviso(
              'Guardamos tu borrador. Puedes seguir cuando quieras desde '
              'Consultas en línea.',
              exito: true,
            ),
          ),
        );
        return;
      }

      emit(state.copiarCon(progreso: 'Enviando tu consulta…'));

      final enviada = await _consultas.enviar(borrador.id);

      emit(
        state.copiarCon(
          guardando: false,
          limpiarProgreso: true,
          borrador: enviada,
          enviada: enviada,
          paso: PasoConsulta.enviada,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          guardando: false,
          limpiarProgreso: true,
          errorGuardar: mensajeDeError(
            error,
            generico: enviar
                ? 'No se pudo enviar la consulta. Intenta de nuevo.'
                : 'No se pudo guardar el borrador. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _alDescartar(
    NuevaConsultaDescartada event,
    Emitter<NuevaConsultaState> emit,
  ) async {
    final borrador = state.borrador;
    if (state.guardando || state.enviada != null) return;

    if (borrador == null) {
      emit(state.copiarCon(eliminada: true));
      return;
    }

    emit(state.copiarCon(guardando: true, progreso: 'Eliminando el borrador…'));

    try {
      await _consultas.eliminar(borrador.id);
      emit(
        state.copiarCon(
          guardando: false,
          limpiarProgreso: true,
          eliminada: true,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          guardando: false,
          limpiarProgreso: true,
          aviso: _aviso(
            mensajeDeError(error, generico: 'No se pudo eliminar el borrador.'),
          ),
        ),
      );
    }
  }

  // ── Dependientes ───────────────────────────────────────────────────

  Future<void> _alRecargarDependientes(
    NuevaConsultaDependientesRecargados event,
    Emitter<NuevaConsultaState> emit,
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
}
