// test/dobles/dobles.dart

/// Dobles de prueba: servicios que contestan lo que la prueba les pide, sin
/// red ni complementos nativos.
library;

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/notificaciones/recordatorios_citas.dart';
import 'package:app_cliniq/core/service/biometria_service.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/portal_service.dart';
import 'package:app_cliniq/features/agendar/dominio/huecos.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/dependientes/data/dependientes_service.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:dio/dio.dart';

/// Un error HTTP con la forma de la API: `{status, message}` y, si se pasa,
/// el `codigo` con que algunas respuestas se distinguen.
DioException errorHttp(int estado, [Object? mensaje, String? codigo]) {
  final opciones = RequestOptions(path: '/prueba');

  return DioException(
    requestOptions: opciones,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: opciones,
      statusCode: estado,
      data: {'status': estado, 'message': ?mensaje, 'codigo': ?codigo},
    ),
  );
}

/// Un error de red: no se llegó al servidor.
DioException errorDeRed() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/prueba'),
  reason: 'sin red',
);

Usuario usuarioDePrueba({
  List<String> legalPendientes = const [],
  bool dosFactores = false,
}) {
  return Usuario({
    'uid': 'u1',
    'nombre': 'Ana María Pérez',
    'email': 'ana@correo.com',
    'role': 3,
    'roles': ['PACIENTE'],
    'permisos': [Permisos.misCitas, Permisos.agendar, Permisos.dependientes],
    'legalPendientes': legalPendientes,
    'dosFactores': dosFactores,
  });
}

/// El servicio de acceso, con respuestas programadas.
class AuthServiceFalso implements AuthService {
  Future<ResultadoDeAcceso> Function(String email, String password)? alEntrar;
  Future<ResultadoDeAcceso> Function(String desafio, String codigo)?
  alVerificar;
  Future<Usuario> Function()? alPedirPerfil;

  final List<String> llamadas = [];

  @override
  Future<ResultadoDeAcceso> iniciarSesion({
    required String email,
    required String password,
  }) {
    llamadas.add('login:$email');
    return alEntrar!(email, password);
  }

  @override
  Future<ResultadoDeAcceso> verificarCodigo({
    required String desafio,
    required String codigo,
  }) {
    llamadas.add('2fa:$desafio:$codigo');
    return alVerificar!(desafio, codigo);
  }

  @override
  Future<Usuario> yo() {
    llamadas.add('me');
    return alPedirPerfil?.call() ?? Future.value(usuarioDePrueba());
  }

  @override
  Future<String> pedirRecuperacion(String email) async =>
      'Si el correo está registrado, te enviamos un enlace.';

  /// Si está puesto, reenviar la confirmación falla con este error.
  Object? errorAlReenviar;

  @override
  Future<String> reenviarConfirmacion(String email) async {
    llamadas.add('reenviar:$email');

    final error = errorAlReenviar;
    if (error != null) throw error;

    return 'Si el correo tiene una cuenta pendiente, te enviamos un enlace.';
  }

  @override
  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {}

  @override
  Future<void> cambiarDosFactores({
    required bool activo,
    required String password,
  }) async {}

  @override
  Future<Usuario> actualizarPerfil(String uid, Map<String, dynamic> campos) =>
      yo();
}

/// La huella: disponible o no, y lo que contesta al verificar.
class BiometriaFalsa implements BiometriaService {
  final bool hay;
  final bool verifica;

  BiometriaFalsa({this.hay = false, this.verifica = true});

  @override
  Future<bool> disponible() async => hay;

  @override
  Future<bool> verificar(String motivo) async => verifica;
}

/// Solo anota lo que le pidieron programar.
class ProgramadorFalso implements ProgramadorDeRecordatorios {
  final List<List<Cita>> programados = [];
  int cancelaciones = 0;

  @override
  Future<void> reprogramar(List<Cita> citas, DateTime ahora) async =>
      programados.add(citas);

  @override
  Future<void> cancelarTodo() async => cancelaciones++;
}

/// El portal, con médicos y ocupados programables.
class PortalFalso implements PortalService {
  List<MedicoPortal> medicosDisponibles;
  List<IntervaloOcupado> Function(String doctorId, DateTime dia) ocupadosDe;

  /// Si está puesto, agendar falla con este error.
  Object? errorAlAgendar;

  final List<NuevaCita> agendadas = [];
  final List<String> reprogramadas = [];
  final List<String> canceladas = [];
  int consultasDeOcupados = 0;

  PortalFalso({
    this.medicosDisponibles = const [],
    List<IntervaloOcupado> Function(String, DateTime)? ocupadosDe,
  }) : ocupadosDe = ocupadosDe ?? ((_, _) => const []);

  @override
  Future<List<MedicoPortal>> medicos({
    String? especialidad,
    String? ciudad,
    TipoCita? modalidad,
  }) async => medicosDisponibles;

  @override
  Future<List<IntervaloOcupado>> ocupados(
    String doctorId,
    DateTime desde,
    DateTime hasta,
  ) async {
    consultasDeOcupados++;
    return ocupadosDe(doctorId, desde);
  }

  @override
  Future<Cita> agendar(NuevaCita cita) async {
    final error = errorAlAgendar;
    if (error != null) throw error;

    agendadas.add(cita);

    return Cita(
      id: 'nueva',
      inicio: cita.inicio,
      fin: cita.fin,
      tipo: cita.tipo,
      estado: EstadoCita.programada,
      doctorId: cita.doctorId,
      motivo: cita.motivo,
    );
  }

  @override
  Future<Cita> reprogramar(String id, DateTime inicio, DateTime fin) async {
    reprogramadas.add(id);

    return Cita(
      id: id,
      inicio: inicio,
      fin: fin,
      tipo: TipoCita.presencial,
      estado: EstadoCita.reagendada,
      doctorId: 'doc',
    );
  }

  @override
  Future<Cita> cancelar(String id, String motivo, {String? detalle}) async {
    canceladas.add('$id:$motivo');

    return Cita(
      id: id,
      inicio: DateTime(2026, 10, 1, 9),
      fin: DateTime(2026, 10, 1, 9, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.cancelada,
      doctorId: 'doc',
    );
  }
}

class DependientesFalso implements DependientesService {
  List<Dependiente> lista;

  DependientesFalso([this.lista = const []]);

  @override
  Future<({List<Dependiente> lista, bool desdeCache})> listar(
    String uid,
  ) async => (lista: lista, desdeCache: false);

  @override
  Future<Dependiente> crear(DatosDependiente datos) async =>
      Dependiente(uid: 'd-nuevo', nombre: datos.nombre);

  @override
  Future<Dependiente> actualizar(String id, DatosDependiente datos) async =>
      Dependiente(uid: id, nombre: datos.nombre);

  @override
  Future<void> eliminar(String id) async {}
}

class CatalogosFalso implements CatalogoService {
  @override
  Future<Map<String, List<String>>> cargar([
    List<String> claves = Catalogos.todos,
  ]) async => {for (final c in claves) c: catalogosDePartida[c] ?? const []};
}

/// Una caché en memoria, reutilizando la de la aplicación.
CacheLocal cacheDePrueba() => CacheEnMemoria();
