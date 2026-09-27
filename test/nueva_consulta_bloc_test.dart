// test/nueva_consulta_bloc_test.dart

import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';
import 'package:app_cliniq/core/archivos/selector_de_archivos.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/data/models/opciones_consulta.dart';
import 'package:app_cliniq/features/consultas/dominio/reglas_consultas.dart';
import 'package:app_cliniq/features/consultas/providers/nueva_consulta_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/nueva_consulta_event.dart';
import 'package:app_cliniq/features/consultas/providers/nueva_consulta_state.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';
import 'dobles/dobles.dart';
import 'dobles/clinica.dart';

/// La consulta nueva paso a paso: para quién, especialidad, motivo, médico,
/// formulario, resumen y envío (borrador → archivos → enviar).
///
/// Ninguna prueba espera un tiempo fijo: cada una espera el estado que le
/// interesa.
void main() {
  late ConsultasFalso servicio;
  late DependientesFalso dependientes;

  setUp(() {
    servicio = ConsultasFalso();
    dependientes = DependientesFalso(const [
      Dependiente(uid: 'dep1', nombre: 'Tomás Pérez', parentesco: 'Hijo/a'),
    ]);
  });

  // Los topes de la configuración de prueba: 30 archivos de hasta 20 MB.
  final config = configDePrueba();
  final maximoAdjuntos = config.telemedicina.maxArchivosConsulta;

  NuevaConsultaBloc crear({
    bool puedeDependientes = true,
    Map<String, dynamic>? telemedicina,
    Map<String, dynamic>? archivos,
  }) {
    final config = configDePrueba(
      telemedicina: telemedicina,
      archivos: archivos,
    );

    return NuevaConsultaBloc(
      consultas: servicio,
      dependientes: dependientes,
      uid: 'u1',
      nombreTitular: 'Ana María Pérez',
      maximoAdjuntos: config.telemedicina.maxArchivosConsulta,
      archivos: config.archivos,
      puedeDependientes: puedeDependientes,
    );
  }

  Future<NuevaConsultaState> esperar(
    NuevaConsultaBloc bloc,
    bool Function(NuevaConsultaState s) condicion,
  ) async {
    if (condicion(bloc.state)) return bloc.state;
    return bloc.stream.firstWhere(condicion);
  }

  /// Camina hasta el formulario del motivo «Lesión en la piel».
  Future<void> hastaElFormulario(
    NuevaConsultaBloc bloc, {
    String para = consultaParaMi,
  }) async {
    bloc.add(const NuevaConsultaIniciada());
    await esperar(bloc, (s) => !s.cargando && s.paso == PasoConsulta.paciente);

    bloc
      ..add(NuevaConsultaParaElegido(para))
      ..add(const NuevaConsultaContinuada())
      ..add(const NuevaConsultaEspecialidadElegida('Dermatología'))
      ..add(const NuevaConsultaMotivoElegido('m-lesion'))
      ..add(const NuevaConsultaMedicoElegido('doc1'));

    await esperar(bloc, (s) => s.paso == PasoConsulta.formulario);
  }

  /// Responde lo requerido, describe y adjunta una foto.
  Future<void> llenar(NuevaConsultaBloc bloc) async {
    bloc
      ..add(const NuevaConsultaRespuestaCambiada('desde', '2026-09-21'))
      ..add(const NuevaConsultaRespuestaCambiada('zona', 'Brazos'))
      ..add(const NuevaConsultaRespuestaCambiada('pica', false))
      ..add(const NuevaConsultaRespuestaCambiada('tamano', '2,5'))
      ..add(const NuevaConsultaDescripcionCambiada('  Manchas rojas.  '))
      ..add(
        NuevaConsultaArchivosElegidos(
          SeleccionDeArchivos(archivos: [fotoLocal()]),
        ),
      );

    await esperar(bloc, (s) => s.adjuntos.isNotEmpty);
  }

  group('Abrir', () {
    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'trae las opciones y los dependientes y empieza por «para quién»',
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.cargando, isFalse);
        expect(s.paso, PasoConsulta.paciente);
        expect(s.especialidades.map((e) => e.nombre), [
          'Dermatología',
          'Pediatría',
        ]);
        expect(s.dependientes.single.uid, 'dep1');
        expect(s.pasosDelRecorrido, hasLength(6));
        expect(servicio.llamadas, ['opciones']);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'sin permiso de dependientes empieza por la especialidad',
      build: () => crear(puedeDependientes: false),
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        expect(bloc.state.paso, PasoConsulta.especialidad);
        expect(bloc.state.dependientes, isEmpty);
        expect(NuevaConsultaBloc.pasoAnterior(bloc.state), isNull);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'sin médicos en línea lo dice, en vez de un formulario vacío',
      setUp: () => servicio.especialidades = const [],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) =>
          expect(bloc.state.error, contains('ningún médico atiende')),
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'si las opciones no llegan, el error para reintentar',
      setUp: () => servicio.errores['opciones'] = [errorDeRed()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        expect(bloc.state.cargando, isFalse);
        expect(bloc.state.error, contains('Sin conexión'));
      },
    );
  });

  group('Paso a paso', () {
    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'especialidad → motivo → médico → formulario, cada uno al tocarlo',
      build: crear,
      act: hastaElFormulario,
      verify: (bloc) {
        final s = bloc.state;
        expect(s.especialidad, 'Dermatología');
        expect(s.motivo?.id, 'm-lesion');
        expect(s.medico?.uid, 'doc1');
        expect(s.campos, hasLength(camposLesion.length));
        expect(NuevaConsultaBloc.pasoAnterior(s), PasoConsulta.medico);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'el formulario incompleto no deja seguir y marca lo que falta',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(const NuevaConsultaContinuada());
        await esperar(bloc, (s) => s.mostrarErrores);
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.paso, PasoConsulta.formulario);
        expect(s.errores.keys, containsAll(['desde', 'zona', 'pica']));
        expect(s.errores[claveDescripcion], isNotNull);
        expect(
          s.errores[claveAdjuntos],
          isNotNull,
          reason: 'el motivo pide un archivo',
        );
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'completo, pasa al resumen',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        await llenar(bloc);
        bloc.add(const NuevaConsultaContinuada());
        await esperar(bloc, (s) => s.paso == PasoConsulta.resumen);
      },
      verify: (bloc) {
        expect(bloc.state.errores, isEmpty);
        expect(bloc.state.lista, isTrue);
        expect(bloc.state.pendientesDeSubir, 1);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'una consulta nueva tiene cambios apenas se escribe algo',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        expect(bloc.state.cambiosSinGuardar, isFalse);

        bloc.add(const NuevaConsultaDescripcionCambiada('Me pica'));
        await esperar(bloc, (s) => s.descripcion.isNotEmpty);
        expect(bloc.state.cambiosSinGuardar, isTrue);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'otra especialidad borra el motivo, el médico y lo respondido',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc
          ..add(const NuevaConsultaRespuestaCambiada('zona', 'Cara'))
          ..add(const NuevaConsultaPasoCambiado(PasoConsulta.especialidad))
          ..add(const NuevaConsultaEspecialidadElegida('Pediatría'));
        await esperar(bloc, (s) => s.especialidad == 'Pediatría');
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.paso, PasoConsulta.motivo);
        expect(s.motivo, isNull);
        expect(s.medico, isNull);
        expect(s.respuestas, isEmpty);
        expect(s.motivosDisponibles.single.id, 'm-fiebre');
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'hacia adelante no se salta con PasoCambiado; una respuesta a una '
      'pregunta ajena se ignora',
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
        bloc
          ..add(const NuevaConsultaPasoCambiado(PasoConsulta.resumen))
          ..add(const NuevaConsultaRespuestaCambiada('ajena', 'x'));
      },
      verify: (bloc) {
        expect(bloc.state.paso, PasoConsulta.paciente);
        expect(bloc.state.respuestas, isEmpty);
      },
    );
  });

  group('Archivos', () {
    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'lo que no es PDF, JPG ni PNG, o pasa de 20 MB, no entra y se dice',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(
          NuevaConsultaArchivosElegidos(
            SeleccionDeArchivos(
              archivos: [
                ArchivoLocal(
                  nombre: 'nota.txt',
                  bytes: Uint8List.fromList('hola'.codeUnits),
                ),
                fotoLocal(),
              ],
              problemas: const ['«video.mp4» pesa 80 MB y el máximo es 20 MB.'],
            ),
          ),
        );
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.adjuntos, hasLength(1));
        expect(s.adjuntos.single, isA<AdjuntoPendiente>());
        expect(s.aviso?.exito, isFalse);
        expect(s.aviso?.mensaje, contains('nota.txt'));
        expect(s.aviso?.mensaje, contains('video.mp4'));
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'hasta $maximoAdjuntos archivos',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(
          NuevaConsultaArchivosElegidos(
            SeleccionDeArchivos(
              archivos: [
                for (var i = 0; i < maximoAdjuntos + 2; i++)
                  fotoLocal('f$i.jpg'),
              ],
            ),
          ),
        );
        await esperar(bloc, (s) => s.adjuntos.isNotEmpty);
      },
      verify: (bloc) {
        expect(bloc.state.adjuntos, hasLength(maximoAdjuntos));
        expect(bloc.state.aviso?.mensaje, contains('hasta $maximoAdjuntos'));
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'el tope de archivos es el de la configuración (maxArchivosConsulta)',
      build: () => crear(telemedicina: {'maxArchivosConsulta': 2}),
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(
          NuevaConsultaArchivosElegidos(
            SeleccionDeArchivos(
              archivos: [for (var i = 0; i < 4; i++) fotoLocal('f$i.jpg')],
            ),
          ),
        );
        await esperar(bloc, (s) => s.adjuntos.isNotEmpty);
      },
      verify: (bloc) {
        expect(bloc.state.maximoAdjuntos, 2);
        expect(bloc.state.adjuntos, hasLength(2));
        expect(bloc.state.cabeOtroAdjunto, isFalse);
        expect(bloc.state.aviso?.mensaje, 'Puedes adjuntar hasta 2 archivos.');
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'el tamaño máximo y los tipos son los de la configuración',
      build: () => crear(
        archivos: {
          'tamanoMaximoMb': 1,
          'tipos': ['application/pdf'],
        },
      ),
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(
          NuevaConsultaArchivosElegidos(
            SeleccionDeArchivos(
              archivos: [
                // Una foto JPG: la clínica solo acepta PDF.
                fotoLocal(),
                // Un PDF de más de 1 MB.
                ArchivoLocal(
                  nombre: 'grande.pdf',
                  bytes: Uint8List.fromList([
                    ...'%PDF-'.codeUnits,
                    ...List.filled(1024 * 1024, 0),
                  ]),
                ),
              ],
            ),
          ),
        );
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (bloc) {
        expect(bloc.state.adjuntos, isEmpty);
        expect(
          bloc.state.aviso?.mensaje,
          allOf(
            contains('no es un PDF.'),
            contains('«grande.pdf» pesa 1,0 MB y el máximo es 1 MB.'),
          ),
        );
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'uno sin subir se quita sin llamar al servidor',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        await llenar(bloc);
        bloc.add(NuevaConsultaAdjuntoQuitado(bloc.state.adjuntos.single));
        await esperar(bloc, (s) => s.adjuntos.isEmpty);
      },
      verify: (_) => expect(servicio.llamadas, ['opciones']),
    );
  });

  group('Enviar', () {
    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'crea el borrador, sube el archivo y envía, en ese orden',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        await llenar(bloc);
        bloc
          ..add(const NuevaConsultaContinuada())
          ..add(const NuevaConsultaConfirmada());
        await esperar(bloc, (s) => s.paso == PasoConsulta.enviada);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'opciones',
          'crear',
          'subir:c-nueva:brazo.jpg',
          'enviar:c-nueva',
        ]);

        final creada = servicio.creadas.single;
        expect(creada.aJson(), {
          'motivoId': 'm-lesion',
          'medicoId': 'doc1',
          'respuestas': {
            'desde': '2026-09-21',
            'zona': 'Brazos',
            'pica': false,
            'tamano': 2.5,
          },
          'descripcion': 'Manchas rojas.',
        });

        final s = bloc.state;
        expect(s.enviada?.estado, EstadoConsulta.enviada);
        expect(s.guardando, isFalse);
        expect(s.progreso, isNull);
        expect(s.adjuntos.single, isA<AdjuntoSubido>());
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'para un dependiente va su pacienteId',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc, para: 'dep1');
        await llenar(bloc);
        bloc.add(const NuevaConsultaConfirmada());
        await esperar(bloc, (s) => s.paso == PasoConsulta.enviada);
      },
      verify: (bloc) {
        expect(servicio.creadas.single.pacienteId, 'dep1');
        expect(bloc.state.pacienteNombre, 'Ana María Pérez');
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'si el archivo no sube, reintentar sigue el mismo borrador: no crea '
      'otra consulta',
      setUp: () => servicio.errores['subir'] = [errorDeRed()],
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        await llenar(bloc);
        bloc.add(const NuevaConsultaConfirmada());

        final fallido = await esperar(
          bloc,
          (s) => !s.guardando && s.errorGuardar != null,
        );
        expect(fallido.errorGuardar, contains('Sin conexión'));
        expect(fallido.fijada, isTrue, reason: 'el borrador ya existe');
        expect(fallido.primerPaso, PasoConsulta.formulario);
        expect(fallido.adjuntos.single, isA<AdjuntoPendiente>());

        bloc.add(const NuevaConsultaConfirmada());
        await esperar(bloc, (s) => s.paso == PasoConsulta.enviada);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'opciones',
          'crear',
          'subir:c-nueva:brazo.jpg',
          'actualizar:c-nueva',
          'subir:c-nueva:brazo.jpg',
          'enviar:c-nueva',
        ]);
        expect(servicio.creadas, hasLength(1));
        expect(servicio.actualizadas.single.descripcion, 'Manchas rojas.');
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'con el formulario incompleto no se envía: vuelve y marca',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc.add(const NuevaConsultaConfirmada());
        await esperar(bloc, (s) => s.mostrarErrores);
      },
      verify: (bloc) {
        expect(bloc.state.paso, PasoConsulta.formulario);
        expect(servicio.llamadas, ['opciones']);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'guardar como borrador: crea y sube, pero no envía',
      build: crear,
      act: (bloc) async {
        await hastaElFormulario(bloc);
        bloc
          ..add(const NuevaConsultaDescripcionCambiada('Todavía escribiendo'))
          ..add(
            NuevaConsultaArchivosElegidos(
              SeleccionDeArchivos(archivos: [fotoLocal()]),
            ),
          )
          ..add(const NuevaConsultaBorradorGuardado());
        await esperar(bloc, (s) => !s.guardando && s.aviso != null);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'opciones',
          'crear',
          'subir:c-nueva:brazo.jpg',
        ]);
        expect(bloc.state.aviso?.exito, isTrue);
        expect(bloc.state.paso, PasoConsulta.formulario);
        expect(bloc.state.borrador?.estado, EstadoConsulta.borrador);
      },
    );
  });

  group('Retomar un borrador', () {
    // Como lo manda la API: con la copia de las preguntas y de si pide un
    // archivo que el borrador tomó del motivo al crearse.
    ConsultaDetalle borrador({
      String estado = 'BORRADOR',
      List<Map<String, dynamic>> campos = camposLesion,
      bool requiereAdjunto = true,
      List<Map<String, dynamic>>? adjuntos,
    }) => ConsultaDetalle.desdeJson(
      consultaJson(
        id: 'b1',
        estado: estado,
        paraDependiente: true,
        pacienteId: 'dep1',
        pacienteNombre: 'Tomás Pérez',
        descripcion: 'Borrador a medias',
        adjuntos: adjuntos ?? [archivoJson('a1')],
        campos: campos,
        requiereAdjunto: requiereAdjunto,
        respuestas: [
          {
            'clave': 'tamano',
            'etiqueta': 'Tamaño aproximado',
            'tipo': 'numero',
            'valor': 2.5,
          },
          {
            'clave': 'zona',
            'etiqueta': 'Zona del cuerpo',
            'tipo': 'seleccion',
            'valor': 'Cara',
          },
        ],
      ),
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'abre en el formulario con todo lo guardado, y lo fijo no se cambia',
      setUp: () => servicio.detalles = [borrador()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
        bloc
          ..add(const NuevaConsultaRetrocedida())
          ..add(const NuevaConsultaEspecialidadElegida('Pediatría'));
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.paso, PasoConsulta.formulario);
        expect(s.fijada, isTrue);
        expect(s.pasosDelRecorrido, [
          PasoConsulta.formulario,
          PasoConsulta.resumen,
        ]);
        expect(s.especialidad, 'Dermatología');
        expect(
          s.motivo?.requiereAdjunto,
          isTrue,
          reason: 'la copia del borrador',
        );
        expect(
          s.motivo?.descripcion,
          'Manchas, granos o heridas que no sanan.',
          reason: 'lo que se enseña sale de las opciones',
        );
        expect(s.medico?.uid, 'doc1');
        expect(s.para, 'dep1');
        expect(s.pacienteNombre, 'Tomás Pérez');
        expect(s.respuestas, {'tamano': '2,5', 'zona': 'Cara'});
        expect(s.descripcion, 'Borrador a medias');
        expect(s.adjuntos.single, isA<AdjuntoSubido>());
      },
    );

    /// «Lesión en la piel» después de que el administrador la editó: otras
    /// preguntas, sin archivo obligatorio y otra descripción.
    List<EspecialidadConsulta> opcionesEditadas({
      bool requiereAdjunto = false,
    }) {
      final datos = opcionesJson();
      final dermatologia = (datos['especialidades'] as List).first as Map;
      final lesion = (dermatologia['motivos'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['_id'] == 'm-lesion');

      lesion
        ..['descripcion'] = 'Descripción nueva del motivo.'
        ..['requiereAdjunto'] = requiereAdjunto
        ..['campos'] = [
          {
            'clave': 'color',
            'etiqueta': 'Color de la lesión',
            'tipo': 'texto',
            'requerido': true,
          },
        ];

      return interpretarOpciones(datos);
    }

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'las preguntas y el archivo obligatorio salen de la copia del '
      'borrador, no del motivo que el administrador editó después',
      setUp: () {
        servicio
          ..especialidades = opcionesEditadas()
          ..detalles = [borrador(adjuntos: const [])];
      },
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.campos.map((c) => c.clave), [
          for (final c in camposLesion) c['clave'],
        ]);
        expect(s.motivo?.requiereAdjunto, isTrue);
        expect(s.motivo?.descripcion, 'Descripción nueva del motivo.');
        expect(s.errores.keys, contains(claveAdjuntos));
        expect(s.errores.keys, isNot(contains('color')));
        expect(s.errores['desde'], 'Responde esta pregunta.');
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'si el borrador no pedía archivo, no se exige aunque el motivo ahora '
      'lo pida',
      setUp: () {
        servicio
          ..especialidades = opcionesEditadas(requiereAdjunto: true)
          ..detalles = [borrador(requiereAdjunto: false, adjuntos: const [])];
      },
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        expect(bloc.state.motivo?.requiereAdjunto, isFalse);
        expect(bloc.state.errores.keys, isNot(contains(claveAdjuntos)));
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'enviar un borrador lo pone al día y lo envía, sin crear otro',
      setUp: () => servicio.detalles = [borrador()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
        bloc
          ..add(const NuevaConsultaRespuestaCambiada('desde', '2026-09-21'))
          ..add(const NuevaConsultaRespuestaCambiada('pica', true))
          ..add(const NuevaConsultaConfirmada());
        await esperar(bloc, (s) => s.paso == PasoConsulta.enviada);
      },
      verify: (_) {
        expect(servicio.llamadas, [
          'opciones',
          'detalle:b1',
          'actualizar:b1',
          'enviar:b1',
        ]);
        // Las vacías van como null: el servidor combina con lo guardado.
        expect(servicio.actualizadas.single.respuestas, {
          'desde': '2026-09-21',
          'zona': 'Cara',
          'pica': true,
          'tamano': 2.5,
          'forma': null,
          'notas': null,
        });
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'salir sin tocar nada no pregunta; con un cambio, sí',
      setUp: () => servicio.detalles = [borrador()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
        expect(bloc.state.cambiosSinGuardar, isFalse);

        bloc.add(const NuevaConsultaRespuestaCambiada('zona', 'Brazos'));
        await esperar(bloc, (s) => s.respuestas['zona'] == 'Brazos');
        expect(bloc.state.cambiosSinGuardar, isTrue);

        bloc.add(const NuevaConsultaRespuestaCambiada('zona', 'Cara'));
        await esperar(bloc, (s) => s.respuestas['zona'] == 'Cara');
        expect(bloc.state.cambiosSinGuardar, isFalse);

        bloc.add(
          NuevaConsultaArchivosElegidos(
            SeleccionDeArchivos(archivos: [fotoLocal()]),
          ),
        );
        await esperar(bloc, (s) => s.pendientesDeSubir == 1);
        expect(bloc.state.cambiosSinGuardar, isTrue);
      },
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'quitar un archivo ya guardado lo borra del servidor',
      setUp: () => servicio.detalles = [borrador()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
        bloc.add(NuevaConsultaAdjuntoQuitado(bloc.state.adjuntos.single));
        await esperar(bloc, (s) => s.adjuntos.isEmpty && s.quitandoId == null);
      },
      verify: (_) => expect(servicio.llamadas.last, 'quitar:b1:a1'),
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'descartar borra el borrador y cierra',
      setUp: () => servicio.detalles = [borrador()],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
        bloc.add(const NuevaConsultaDescartada());
        await esperar(bloc, (s) => s.eliminada);
      },
      verify: (_) => expect(servicio.llamadas.last, 'eliminar:b1'),
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'descartar sin borrador solo cierra',
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada());
        await esperar(bloc, (s) => !s.cargando);
        bloc.add(const NuevaConsultaDescartada());
        await esperar(bloc, (s) => s.eliminada);
      },
      verify: (_) => expect(servicio.llamadas, ['opciones']),
    );

    blocTest<NuevaConsultaBloc, NuevaConsultaState>(
      'una consulta ya enviada no se retoma como borrador',
      setUp: () => servicio.detalles = [borrador(estado: 'ENVIADA')],
      build: crear,
      act: (bloc) async {
        bloc.add(const NuevaConsultaIniciada(borradorId: 'b1'));
        await esperar(bloc, (s) => !s.cargando);
      },
      verify: (bloc) => expect(bloc.state.error, contains('ya se envió')),
    );
  });
}
