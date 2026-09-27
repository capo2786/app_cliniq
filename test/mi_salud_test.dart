// test/mi_salud_test.dart

import 'dart:async';

import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/mi_salud/data/mi_salud_service.dart';
import 'package:app_cliniq/features/mi_salud/data/models/mi_salud.dart';
import 'package:app_cliniq/features/mi_salud/dominio/reglas_mi_salud.dart';
import 'package:app_cliniq/features/mi_salud/providers/documento_cubit.dart';
import 'package:app_cliniq/features/mi_salud/providers/mi_salud_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mi_salud.dart';

/// Mi salud: la lectura de la respuesta, el cálculo del embarazo, la copia
/// sin red y el cubit que elige de quién se ve.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  group('La lectura de Mi salud', () {
    test('la ficha, las mediciones y cada atención con sus documentos', () {
      final salud = MiSalud.desdeJson(miSaludJson());

      expect(salud.paciente.nombre, 'Ana María Pérez');
      expect(salud.paciente.edad, 34);
      expect(salud.paciente.sexo, 'F');
      expect(salud.paciente.tipoSangre, 'O+');
      expect(salud.paciente.alergias, 'Penicilina');
      expect(salud.paciente.embarazoActual, isFalse);

      // Hora congelada: las 23:18 de la clínica, sin moverla por la zona.
      expect(salud.ultimosSignos!.fecha, DateTime(2026, 9, 25, 23, 18, 52));
      expect(salud.ultimosSignos!.presionSistolica, 150);
      expect(salud.ultimosSignos!.imc, 25.7);
      expect(salud.ultimosSignos!.glucemiaMgDl, isNull);

      final atencion = salud.atenciones.single;
      expect(atencion.inicio, DateTime(2026, 9, 25, 23, 18, 52));
      expect(atencion.tipo, 'TELEMEDICINA');
      expect(atencion.proximoControl, DateTime(2026, 10, 10));
      expect(atencion.diagnosticos.map((d) => d.porConfirmar), [false, true]);

      final receta = atencion.recetas.single;
      expect(receta.fecha, DateTime(2026, 9, 25, 23, 21, 20));
      expect(receta.anulada, isFalse);
      expect(receta.items.single.nombreCompleto, 'Amoxicilina 500 mg Cápsula');
      expect(receta.items.single.posologia, '1 cápsula, Cada 8 horas, 10 días');

      final orden = atencion.ordenes.single;
      expect(orden.tipo, TipoOrden.laboratorio);
      expect(orden.items, hasLength(2));
      expect(orden.items.last.codigo, 'PCR');
      expect(orden.urgente, isFalse);
    });

    test('sin paciente no es Mi salud', () {
      expect(
        () => MiSalud.desdeJson({'atenciones': []}),
        throwsFormatException,
      );
      expect(() => MiSalud.desdeJson([]), throwsFormatException);
    });

    test('lo ilegible se salta y lo demás se enseña', () {
      final salud = MiSalud.desdeJson(
        miSaludJson(
          atenciones: [
            {'inicio': '2026-09-01T10:00:00.000Z'},
            atencionJson(
              recetas: [
                {'items': []},
                recetaJson(id: 'r2'),
              ],
              proximoControl: null,
            ),
          ],
          conSignos: false,
        ),
      );

      expect(salud.ultimosSignos, isNull);
      expect(salud.atenciones, hasLength(1));
      expect(salud.atenciones.single.recetas.single.id, 'r2');
      expect(salud.atenciones.single.proximoControl, isNull);
    });

    test('una receta anulada y una orden urgente de imagen', () {
      final receta = Receta.desdeJson(
        recetaJson(estado: 'ANULADA', anuladaMotivo: 'Dosis equivocada'),
      );
      expect(receta.anulada, isTrue);
      expect(receta.anuladaMotivo, 'Dosis equivocada');

      final orden = Orden.desdeJson(
        ordenJson(tipo: 'IMAGEN', prioridad: 'URGENTE'),
      );
      expect(orden.tipo, TipoOrden.imagen);
      expect(orden.urgente, isTrue);
      expect(nombreDelTipoDeOrden(orden.tipo), 'Imagen');
      expect(nombreDelTipoDeOrden(TipoOrden.desdeCodigo('RAYOS')), 'Orden');
    });
  });

  group('Certificados de reposo y firma electrónica', () {
    test('Mi salud trae los certificados de cada atención', () {
      final salud = MiSalud.desdeJson(
        miSaludJson(
          atenciones: [
            atencionJson(
              certificados: [
                certificadoJson(),
                {'dias': 2},
              ],
            ),
          ],
        ),
      );

      // El ilegible (sin identificador) se salta.
      final certificado = salud.atenciones.single.certificados.single;
      expect(certificado.id, 'c1');
      expect(certificado.dias, 3);
      expect(certificado.diasEnLetras, 'tres');
      expect(certificado.fechaDesde, DateTime(2026, 9, 26));
      expect(certificado.fechaHasta, DateTime(2026, 9, 28));
      expect(certificado.tipoReposo, 'ABSOLUTO');
      expect(certificado.absoluto, isTrue);
      expect(certificado.contingencia, 'ENFERMEDAD_GENERAL');
      expect(certificado.modalidad, 'TELEMEDICINA');
      expect(certificado.destinatario, 'EMPLEADOR');
      expect(
        certificado.recomendaciones,
        'Hidratación abundante y evitar el frío.',
      );
      expect(certificado.codigoVerificacion, 'CR7Q2MXK9P');
    });

    test(
      'una atención abierta trae solo lo firmado, sin contenido clínico',
      () {
        final salud = MiSalud.desdeJson(
          miSaludJson(
            atenciones: [
              atencionEnCursoJson(certificados: [certificadoJson(id: 'c9')]),
              atencionJson(),
            ],
          ),
        );

        final abierta = salud.atenciones.first;
        expect(abierta.enCurso, isTrue);
        expect(abierta.diagnosticos, isEmpty);
        expect(abierta.plan, isEmpty);
        expect(abierta.motivoConsulta, isEmpty);
        expect(abierta.certificados.single.id, 'c9');
        expect(salud.atenciones.last.enCurso, isFalse);
      },
    );

    test('sin fechaHasta se calcula como el servidor: desde + días − 1', () {
      final certificado = CertificadoReposo.desdeJson(
        certificadoJson(dias: 3, fechaHasta: null),
      );
      expect(certificado.fechaHasta, DateTime(2026, 9, 28));

      final conHora = CertificadoReposo.desdeJson({
        ...certificadoJson(fechaHasta: null),
        'fechaDesde': '2026-09-30T00:00:00.000Z',
        'dias': 2,
      });
      // El día escrito, sin moverlo por la zona; cruza de mes.
      expect(conHora.fechaDesde, DateTime(2026, 9, 30));
      expect(conHora.fechaHasta, DateTime(2026, 10, 1));

      expect(
        () => CertificadoReposo.desdeJson({'dias': 3}),
        throwsFormatException,
      );
    });

    test('el diagnóstico solo si el servidor lo manda y no está reservado', () {
      final reservado = CertificadoReposo.desdeJson(
        certificadoJson(mostrarDiagnostico: false),
      );
      expect(reservado.diagnosticoVisible, isFalse);
      expect(reservado.diagnosticoReservado, isTrue);

      final autorizado = CertificadoReposo.desdeJson(
        certificadoJson(mostrarDiagnostico: true),
      );
      expect(autorizado.diagnosticoVisible, isTrue);
      expect(autorizado.diagnosticoReservado, isFalse);

      final sinBandera = CertificadoReposo.desdeJson(
        certificadoJson(mostrarDiagnostico: null),
      );
      expect(sinBandera.diagnosticoVisible, isTrue);

      final noLoMando = CertificadoReposo.desdeJson(
        certificadoJson(mostrarDiagnostico: true, conDiagnostico: false),
      );
      expect(noLoMando.diagnosticoVisible, isFalse);
    });

    test('la firma, con la forma del documento o la resumida', () {
      final receta = Receta.desdeJson(
        recetaJson(firmada: true, pdfDisponible: true),
      );
      expect(receta.firmado, isTrue);
      expect(receta.pdfDisponible, isTrue);
      expect(receta.puedeVerPdf, isTrue);
      expect(receta.firma!.firmadoPor, 'LUIS ALBERTO MORA SALAZAR');
      expect(receta.firma!.emisor, 'Security Data');
      expect(receta.firma!.firmadoEn, DateTime.utc(2026, 9, 26, 15, 15));
      expect(receta.firma!.sha256, huellaDePrueba);

      final resumida = FirmaElectronica.desdeJson({
        'firmadoPor': 'Luis Mora',
        'emisor': 'BCE',
        'firmadoEn': '2026-09-26T15:15:00.000Z',
        'sha256': huellaDePrueba.toUpperCase(),
      });
      expect(resumida!.firmadoPor, 'Luis Mora');
      expect(resumida.emisor, 'BCE');
      expect(resumida.sha256, huellaDePrueba);

      // Una huella que no es sha256 no se usa.
      expect(FirmaElectronica.desdeJson({'sha256': 'abc'})!.sha256, isNull);
    });

    test('sin firmar, en curso o sin PDF no se ofrece «Ver PDF»', () {
      final sinFirma = Receta.desdeJson(recetaJson());
      expect(sinFirma.firmado, isFalse);
      expect(sinFirma.firma, isNull);
      expect(sinFirma.puedeVerPdf, isFalse);

      final enCurso = Receta.desdeJson({
        ...recetaJson(),
        'firma': {'estado': 'EN_CURSO', 'preparacionId': 'p1'},
      });
      expect(enCurso.firmado, isFalse);
      expect(enCurso.firma, isNull);

      // Solo con el estado de la firma, sin el `firmado` del portal.
      final soloEstado = Receta.desdeJson({
        ...recetaJson(),
        'firmado': null,
        'firma': firmaJson(),
      });
      expect(soloEstado.firmado, isTrue);

      final firmadaSinPdf = CertificadoReposo.desdeJson(
        certificadoJson(pdfDisponible: false),
      );
      expect(firmadaSinPdf.firmado, isTrue);
      expect(firmadaSinPdf.puedeVerPdf, isFalse);

      final anulado = CertificadoReposo.desdeJson(
        certificadoJson(estado: 'ANULADA', anuladoMotivo: 'Fechas erradas'),
      );
      expect(anulado.pdfDisponible, isTrue);
      expect(anulado.puedeVerPdf, isFalse);
      expect(anulado.anuladaMotivo, 'Fechas erradas');
    });

    test('los nombres de los códigos y la firma en palabras', () {
      final certificado = CertificadoReposo.desdeJson(certificadoJson());

      expect(resumenDelReposo(certificado), 'Reposo absoluto · 3 días');
      expect(
        resumenDelReposo(
          CertificadoReposo.desdeJson(
            certificadoJson(dias: 1, tipoReposo: 'RELATIVO'),
          ),
        ),
        'Reposo relativo · 1 día',
      );
      expect(
        nombreDeLaContingencia('ACCIDENTE_TRABAJO'),
        'Accidente de trabajo',
      );
      expect(nombreDeLaContingencia('MATERNIDAD'), 'Maternidad');
      expect(nombreDeLaContingencia('NUEVA'), 'NUEVA');
      expect(
        nombreDelDestinatario('INSTITUCION_EDUCATIVA'),
        'Institución educativa',
      );
      expect(nombreDelTipoDeReposo('RELATIVO'), 'Relativo');

      // 15:15 UTC son las 10:15 en Guayaquil.
      expect(
        textoDeLaFirma(certificado.firma),
        'Firmado electrónicamente por LUIS ALBERTO MORA SALAZAR el sábado 26 '
        'de septiembre de 2026 a las 10:15',
      );
      expect(textoDeLaFirma(null), 'Firmado electrónicamente');
    });

    test(
      'el servicio pide el certificado por su ruta y guarda la copia',
      () async {
        final cache = CacheEnMemoria();
        var hayRed = true;
        final api = DioGrabador({
          'GET /portal/certificados/c1': (_) {
            if (!hayRed) throw errorDeRed();
            return certificadoJson();
          },
        });
        final servicio = MiSaludService(api.dio, cache);

        final certificado = await servicio.certificado('u1', 'c1');
        expect(api.claves, ['GET /portal/certificados/c1']);
        expect(certificado.documento.dias, 3);
        expect(certificado.desdeCache, isFalse);

        hayRed = false;
        final sinRed = await servicio.certificado('u1', 'c1');
        expect(sinRed.desdeCache, isTrue);
        expect(sinRed.documento.fechaHasta, DateTime(2026, 9, 28));

        await cache.vaciarDatosPersonales();
        await expectLater(
          servicio.certificado('u1', 'c1'),
          throwsA(isA<DioException>()),
        );
      },
    );
  });

  group('Las reglas', () {
    test('embarazo: semanas y días desde la FUM y fecha probable', () {
      final datos = datosGestacionales(
        '2026-06-01',
        280,
        DateTime(2026, 9, 27, 18),
      );

      expect(datos, isNotNull);
      expect(datos!.semanas, 16);
      expect(datos.dias, 6);
      expect(datos.fpp, DateTime(2027, 3, 8));
    });

    test('embarazo: con los días de la clínica, otra fecha probable', () {
      final datos = datosGestacionales('2026-06-01', 283, DateTime(2026, 9, 1));
      expect(datos!.fpp, DateTime(2027, 3, 11));
    });

    test('embarazo: una FUM futura, imposible o muy vieja no se cuenta', () {
      final hoy = DateTime(2026, 9, 27);
      expect(datosGestacionales('2026-10-01', 280, hoy), isNull);
      expect(datosGestacionales('2026-02-30', 280, hoy), isNull);
      expect(datosGestacionales('2025-10-01', 280, hoy), isNull);
      expect(datosGestacionales(null, 280, hoy), isNull);
    });

    test('números y presión como se escriben', () {
      expect(numeroLegible(70), '70');
      expect(numeroLegible(25.7), '25,7');
      expect(presionLegible(150, 95), '150/95');
      expect(presionLegible(150, null), '150');
      expect(presionLegible(null, null), isNull);
      expect(examenes(1), '1 examen');
      expect(examenes(3), '3 exámenes');
    });
  });

  group('El servicio', () {
    late CacheLocal cache;
    late bool hayRed;
    late DioGrabador api;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      api = DioGrabador({
        'GET /portal/mi-salud': (pedido) {
          if (!hayRed) throw errorDeRed();
          final para = pedido.queryParameters['pacienteId'] as String?;
          return para == null
              ? miSaludJson()
              : miSaludJson(uid: para, nombre: 'Tomás Pérez');
        },
        'GET /portal/recetas/r1': (_) {
          if (!hayRed) throw errorDeRed();
          return recetaJson();
        },
        'GET /portal/ordenes/o1': (_) {
          if (!hayRed) throw errorDeRed();
          return ordenJson();
        },
      });
    });

    MiSaludService servicio() => MiSaludService(api.dio, cache);

    test('el titular sin pacienteId; un dependiente, con el suyo', () async {
      final propia = await servicio().cargar('u1');
      final deTomas = await servicio().cargar('u1', pacienteId: 'd1');

      expect(propia.datos.paciente.nombre, 'Ana María Pérez');
      expect(deTomas.datos.paciente.nombre, 'Tomás Pérez');
      expect(api.pedidos.first.queryParameters, isEmpty);
      expect(api.pedidos.last.queryParameters, {'pacienteId': 'd1'});
    });

    test('sin red, la última copia de esa misma persona', () async {
      await servicio().cargar('u1');
      await servicio().cargar('u1', pacienteId: 'd1');
      hayRed = false;

      final propia = await servicio().cargar('u1');
      final deTomas = await servicio().cargar('u1', pacienteId: 'd1');

      expect(propia.desdeCache, isTrue);
      expect(propia.guardadaEn, isNotNull);
      expect(propia.datos.paciente.nombre, 'Ana María Pérez');
      expect(deTomas.datos.paciente.nombre, 'Tomás Pérez');
    });

    test('sin red y sin copia, el error: nada inventado', () async {
      hayRed = false;

      await expectLater(servicio().cargar('u1'), throwsA(isA<DioException>()));
    });

    test('un 404 no se tapa con la copia', () async {
      await servicio().cargar('u1', pacienteId: 'd1');
      api.rutas['GET /portal/mi-salud'] = (_) =>
          throw errorHttp(404, 'Dependiente no encontrado');

      await expectLater(
        servicio().cargar('u1', pacienteId: 'd1'),
        throwsA(isA<DioException>()),
      );
    });

    test('la copia es de quien entró: se borra al cerrar sesión', () async {
      await servicio().cargar('u1');
      await cache.vaciarDatosPersonales();

      expect(await servicio().guardada('u1'), isNull);
    });

    test('receta y orden por su ruta, con copia para la farmacia', () async {
      final receta = await servicio().receta('u1', 'r1');
      final orden = await servicio().orden('u1', 'o1');

      expect(receta.documento.codigoVerificacion, 'UC7F6DB5UU');
      expect(orden.documento.items, hasLength(2));

      hayRed = false;
      final sinRed = await servicio().receta('u1', 'r1');
      expect(sinRed.desdeCache, isTrue);
      expect(sinRed.documento.items.single.medicamento, 'Amoxicilina');

      await expectLater(
        servicio().orden('u1', 'o-otra'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('El cubit', () {
    late CacheLocal cache;
    late Map<String, Completer<Object?>> pendientes;
    late Dio dio;

    /// Un pedido que la prueba contesta cuando quiere. Un error contestado
    /// antes de que el pedido salga no cuenta como error sin atender.
    Completer<Object?> nuevo() => Completer<Object?>()..future.ignore();

    /// Cada pedido espera a que la prueba lo conteste.
    setUp(() {
      cache = CacheEnMemoria();
      pendientes = {};
      dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (pedido, manejador) async {
              final para = pedido.queryParameters['pacienteId'] ?? 'u1';
              final completer = pendientes.putIfAbsent('$para', nuevo);

              try {
                final datos = await completer.future;
                manejador.resolve(
                  Response<dynamic>(
                    requestOptions: pedido,
                    statusCode: 200,
                    data: datos,
                  ),
                );
              } on DioException catch (error) {
                manejador.reject(
                  DioException(
                    requestOptions: pedido,
                    type: error.type,
                    error: error.error,
                    response: error.response == null
                        ? null
                        : Response<dynamic>(
                            requestOptions: pedido,
                            statusCode: error.response!.statusCode,
                            data: error.response!.data,
                          ),
                  ),
                );
              }
            },
          ),
        );
    });

    Completer<Object?> pedido(String para) =>
        pendientes.putIfAbsent(para, nuevo);

    MiSaludCubit crear({List<Dependiente>? dependientes}) => MiSaludCubit(
      servicio: MiSaludService(dio, cache),
      uid: 'u1',
      dependientes: dependientes == null
          ? null
          : DependientesFalso(dependientes),
    );

    test('al abrir: los dependientes y la salud del titular', () async {
      final cubit = crear(
        dependientes: const [Dependiente(uid: 'd1', nombre: 'Tomás Pérez')],
      );
      addTearDown(cubit.close);

      final carga = cubit.iniciar();
      await cubit.stream.firstWhere((s) => s.carga == CargaMiSalud.cargando);
      pedido('u1').complete(miSaludJson());
      await carga;

      expect(cubit.state.carga, CargaMiSalud.lista);
      expect(cubit.state.datos!.paciente.nombre, 'Ana María Pérez');
      expect(cubit.state.dependientes.single.nombre, 'Tomás Pérez');
      expect(cubit.state.desdeCache, isFalse);
    });

    test('sin permiso de dependientes, solo el titular', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      pedido('u1').complete(miSaludJson());
      await cubit.iniciar();

      expect(cubit.state.dependientes, isEmpty);
    });

    test('al cambiar de persona no se ve la anterior, y una respuesta que '
        'llega tarde se descarta', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      final titular = cubit.cargar();
      await cubit.stream.firstWhere((s) => s.carga == CargaMiSalud.cargando);

      final dependiente = cubit.elegir('d1');
      expect(cubit.state.para, 'd1');
      expect(cubit.state.datos, isNull);

      pedido('u1').complete(miSaludJson());
      await titular;
      expect(cubit.state.datos, isNull);

      pedido('d1').complete(miSaludJson(uid: 'd1', nombre: 'Tomás Pérez'));
      await dependiente;
      expect(cubit.state.datos!.paciente.nombre, 'Tomás Pérez');

      // Volver al titular: sin nada en pantalla, primero su copia.
      pendientes.remove('u1');
      final otraVez = cubit.elegir('');
      await cubit.stream.firstWhere((s) => s.refrescando);
      expect(cubit.state.datos!.paciente.nombre, 'Ana María Pérez');
      expect(cubit.state.desdeCache, isTrue);
      pedido('u1').complete(miSaludJson());
      await otraVez;
      expect(cubit.state.desdeCache, isFalse);
    });

    test('sin red y sin copia: el error con su mensaje, sin datos', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      pedido('u1').completeError(errorDeRed());
      await cubit.cargar();

      expect(cubit.state.carga, CargaMiSalud.error);
      expect(cubit.state.datos, isNull);
      expect(cubit.state.error, contains('Sin conexión'));
    });

    test('un error con la copia en pantalla queda como aviso', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      pedido('u1').complete(miSaludJson());
      await cubit.cargar();

      pendientes.remove('u1');
      pedido('u1').completeError(errorHttp(500));
      await cubit.cargar();

      expect(cubit.state.carga, CargaMiSalud.lista);
      expect(cubit.state.datos, isNotNull);
      expect(cubit.state.error, isNotNull);
    });
  });

  group('El documento', () {
    test('arranca con el de la lista y se pone al día con su ruta', () async {
      final inicial = Receta.desdeJson(recetaJson(medicamento: 'Viejo'));
      final cubit = DocumentoCubit<Receta>(
        () async => ResultadoDocumento(
          documento: Receta.desdeJson(recetaJson(medicamento: 'Nuevo')),
        ),
        inicial: inicial,
      );
      addTearDown(cubit.close);

      expect(cubit.state.carga, CargaDocumento.lista);
      expect(cubit.state.documento!.items.single.medicamento, 'Viejo');

      await cubit.cargar();
      expect(cubit.state.documento!.items.single.medicamento, 'Nuevo');
    });

    test(
      'si falla, se queda el que había y se avisa; sin nada, el error',
      () async {
        final conInicial = DocumentoCubit<Orden>(
          () async => throw errorDeRed(),
          inicial: Orden.desdeJson(ordenJson()),
        );
        final sinNada = DocumentoCubit<Orden>(() async => throw errorHttp(404));
        addTearDown(conInicial.close);
        addTearDown(sinNada.close);

        await conInicial.cargar();
        await sinNada.cargar();

        expect(conInicial.state.carga, CargaDocumento.lista);
        expect(conInicial.state.documento, isNotNull);
        expect(conInicial.state.error, isNotNull);
        expect(sinNada.state.carga, CargaDocumento.error);
        expect(sinNada.state.error, 'No se encontró lo que buscabas.');
      },
    );
  });
}
