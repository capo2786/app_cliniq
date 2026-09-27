// test/contrato_api_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/portal_service.dart';
import 'package:app_cliniq/features/auth/data/acceso.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se lee y se manda a la API, con la forma exacta del gateway.
void main() {
  group('Acceso', () {
    test('200 con token es un acceso concedido', () {
      final resultado = interpretarAcceso({
        'access_token': 'jwt',
        'expires_in': 28800,
        'user': {
          'uid': 'u1',
          'nombre': 'Ana',
          'legalPendientes': ['TERMINOS'],
        },
      });

      expect(resultado, isA<AccesoConcedido>());
      final acceso = resultado as AccesoConcedido;
      expect(acceso.token, 'jwt');
      expect(acceso.expiraEnSegundos, 28800);
      expect(acceso.usuario.legalPendientes, ['TERMINOS']);
    });

    test('200 con requiere2fa pide el código, sin token', () {
      final resultado = interpretarAcceso({
        'requiere2fa': true,
        'desafio': 'abc',
        'destino': 'a***@correo.com',
      });

      expect(resultado, isA<SegundoFactorRequerido>());
      expect((resultado as SegundoFactorRequerido).destino, 'a***@correo.com');
    });

    test('una página de portal cautivo no es una respuesta de la API', () {
      expect(
        () => interpretarAcceso('<html>'),
        throwsA(isA<RespuestaInesperada>()),
      );
      expect(
        () => interpretarAcceso({'user': {}}),
        throwsA(isA<RespuestaInesperada>()),
      );
    });

    test('solo se mandan los campos propios que la API deja cambiar', () {
      final filtrados = CamposEditables.filtrar({
        'nombre': 'Ana',
        'email': 'otro@correo.com',
        'cedula': '1710034065',
        'alergias': 'Penicilina',
        'roles': ['ADMIN'],
      });

      expect(filtrados.keys, containsAll(['nombre', 'alergias']));
      expect(filtrados.keys, isNot(contains('email')));
      expect(filtrados.keys, isNot(contains('cedula')));
      expect(filtrados.keys, isNot(contains('roles')));
    });
  });

  group('Cómo se ofrece entrar', () {
    test('la primera vez solo queda escribir', () {
      final modo = AccesoRapido.decidir(
        hayCredenciales: false,
        biometriaDisponible: true,
        biometriaActiva: true,
      );

      expect(modo, ModoDeAcceso.primeraVez);
      expect(AccesoRapido.precargaCorreo(modo), isFalse);
    });

    test('con credenciales, huella disponible y activa: entra con huella', () {
      final modo = AccesoRapido.decidir(
        hayCredenciales: true,
        biometriaDisponible: true,
        biometriaActiva: true,
      );

      expect(modo, ModoDeAcceso.huella);
      expect(AccesoRapido.precargaCorreo(modo), isTrue);
      // La contraseña nunca se escribe sola: sale solo tras la huella.
      expect(AccesoRapido.precargaContrasena(modo), isFalse);
    });

    test('con la huella apagada en el perfil, se escribe la contraseña', () {
      expect(
        AccesoRapido.decidir(
          hayCredenciales: true,
          biometriaDisponible: true,
          biometriaActiva: false,
        ),
        ModoDeAcceso.credencialesGuardadas,
      );
    });
  });

  group('Mis citas', () {
    test('lee la forma de /agenda/paciente/mis-citas sin mover las horas', () {
      final citas = interpretarCitas([
        {
          '_id': 'c1',
          'title': 'Tomás Pérez',
          'start': '2026-09-28T09:00:00.000Z',
          'end': '2026-09-28T09:30:00.000Z',
          'type': 'TELEMEDICINA',
          'status': 'REAGENDADA',
          'doctorId': 'doc',
          'doctorName': 'Ana Pérez',
          'doctorSpecialty': 'Pediatría',
          'reason': 'Control',
          'pacienteNombre': 'Tomás Pérez',
          'pacienteId': 'dep1',
          'paraDependiente': true,
        },
        {'_id': 'rota', 'start': 'no es fecha', 'end': 'tampoco'},
      ]);

      expect(citas, hasLength(1), reason: 'la cita ilegible se descarta');
      final c = citas.single;
      expect(c.inicio, DateTime(2026, 9, 28, 9));
      expect(c.fin, DateTime(2026, 9, 28, 9, 30));
      expect(c.tipo, TipoCita.telemedicina);
      expect(c.estado, EstadoCita.reagendada);
      expect(c.pendiente, isTrue);
      expect(c.medicoVisible, 'Ana Pérez', reason: 'sin título antepuesto');
      expect(c.paraDependiente, isTrue);
      expect(c.pacienteNombre, 'Tomás Pérez');
    });

    test('la copia guardada se vuelve a leer igual', () {
      final original = Cita(
        id: 'c1',
        inicio: DateTime(2026, 9, 28, 9),
        fin: DateTime(2026, 9, 28, 9, 30),
        tipo: TipoCita.asincrona,
        estado: EstadoCita.programada,
        doctorId: 'doc',
        medico: 'Ana',
      );

      expect(Cita.desdeJson(original.aJson()), original);
    });
  });

  group('Portal', () {
    test('lee un médico del portal; sin modalidades, ofrece las tres', () {
      final m = MedicoPortal.desdeJson({
        'uid': 'doc',
        'nombre': 'Ana Pérez',
        'especialidad': 'Pediatría',
        'ciudad': 'Quito',
        'modalidades': [],
        'horariosAtencion': [
          {
            'dia': 'Lunes',
            'activo': true,
            'rangos': [
              {'inicio': '08:00', 'fin': '12:00'},
            ],
          },
        ],
        'configAgenda': {
          'duraciones': {'PRESENCIAL': 40},
          'margenMinutos': 5,
          'limiteDiario': 8,
        },
        'bloqueos': [
          {'desde': '2026-10-01', 'hasta': '2026-10-02', 'motivo': 'Congreso'},
          {'desde': 'mal'},
        ],
      });

      expect(m.modalidadesOfrecidas, TipoCita.values);
      expect(m.configAgenda?.duraciones['PRESENCIAL'], 40);
      expect(m.configAgenda?.limiteDiario, 8);
      expect(m.bloqueos, hasLength(1));
      expect(m.horariosAtencion.single.rangos.single.fin, '12:00');
    });

    test('las modalidades se ordenan siempre igual', () {
      final m = MedicoPortal.desdeJson({
        'uid': 'doc',
        'nombre': 'Ana',
        'modalidades': ['ASINCRONA', 'PRESENCIAL'],
      });

      expect(m.modalidadesOfrecidas, [TipoCita.presencial, TipoCita.asincrona]);
    });

    test('una cita nueva se manda en hora local sin zona', () {
      final json = NuevaCita(
        doctorId: 'doc',
        inicio: DateTime(2026, 9, 28, 9),
        fin: DateTime(2026, 9, 28, 9, 30),
        tipo: TipoCita.presencial,
        motivo: '  Dolor de cabeza  ',
        pacienteId: 'dep1',
      ).aJson();

      expect(json, {
        'doctorId': 'doc',
        'start': '2026-09-28T09:00:00',
        'end': '2026-09-28T09:30:00',
        'type': 'PRESENCIAL',
        'reason': 'Dolor de cabeza',
        'pacienteId': 'dep1',
      });
    });

    test('para uno mismo no se manda pacienteId', () {
      final json = NuevaCita(
        doctorId: 'doc',
        inicio: DateTime(2026, 9, 28, 9),
        fin: DateTime(2026, 9, 28, 9, 30),
        tipo: TipoCita.presencial,
        motivo: 'Control',
      ).aJson();

      expect(json.containsKey('pacienteId'), isFalse);
    });

    test('un dependiente manda lo opcional solo si se llenó', () {
      final json = const DatosDependiente(
        nombre: ' Tomás ',
        parentesco: 'Hijo/a',
        fechaNacimiento: '2018-04-02',
      ).aJson();

      expect(json['nombre'], 'Tomás');
      expect(json.containsKey('cedula'), isFalse);
      expect(json.containsKey('sexo'), isFalse);
      expect(json['alergias'], '');
    });
  });

  group('Catálogos y documentos legales', () {
    test('el lote trae los elementos activos completos, por clave', () {
      final lote = interpretarLote({
        'MOTIVO_CANCELACION_PACIENTE': [
          {
            'codigo': 'NO_PUEDO',
            'nombre': 'No puedo asistir',
            'descripcion': 'Otro compromiso',
            'color': '#ff0000',
            'icono': 'ban',
            'orden': 1,
            'esPorDefecto': true,
            'isActive': true,
          },
          {'codigo': 'VIEJO', 'nombre': 'Retirado', 'isActive': false},
        ],
        'parentesco_dependiente': [
          {'codigo': 'MADRE', 'nombre': 'Madre'},
        ],
      });

      expect(lote[Catalogos.motivoCancelacionPaciente], [
        const ItemCatalogo(
          codigo: 'NO_PUEDO',
          nombre: 'No puedo asistir',
          descripcion: 'Otro compromiso',
          color: '#ff0000',
          icono: 'ban',
          orden: 1,
          esPorDefecto: true,
        ),
      ]);
      expect(lote[Catalogos.parentescoDependiente]!.single.codigo, 'MADRE');
    });

    test('cada documento se abre por el nombre corto que manda la API', () {
      expect(
        const DocumentoPendiente(
          clave: 'USO_ACEPTABLE',
          version: '1.0',
          titulo: 'x',
          slug: 'uso-aceptable',
        ).url,
        'https://cliniq.gcaicedo-proyectos.com/legal/uso-aceptable',
      );
      expect(
        const DocumentoPendiente(clave: 'NUEVO', version: '1', titulo: 'x').url,
        isNull,
        reason: 'sin slug no se arma ninguna dirección',
      );
    });

    test('mis aceptaciones: aceptadas y pendientes, con título y slug', () {
      final datos = interpretarAceptaciones({
        'aceptaciones': [
          {
            'clave': 'TERMINOS',
            'version': '1.0',
            'titulo': 'Términos de uso',
            'slug': 'terminos',
            'aceptadoEn': '2026-09-20T14:00:00.000Z',
          },
        ],
        'pendientes': [
          {
            'clave': 'PRIVACIDAD',
            'version': '1.0',
            'titulo': 'Política de privacidad',
            'slug': 'privacidad',
          },
        ],
      });

      expect(datos.aceptaciones.single.titulo, 'Términos de uso');
      expect(datos.aceptaciones.single.slug, 'terminos');
      expect(datos.pendientes.single.clave, 'PRIVACIDAD');
      expect(datos.pendientes.single.slug, 'privacidad');
    });
  });
}
