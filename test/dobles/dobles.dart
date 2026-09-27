// test/dobles/dobles.dart

/// Dobles de prueba: servicios que contestan lo que la prueba les pide, sin
/// red ni complementos nativos.
library;

import 'package:app_cliniq/core/notificaciones/recordatorios_citas.dart';
import 'package:app_cliniq/core/service/biometria_service.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/models/turnos.dart';
import 'package:app_cliniq/features/agendar/data/portal_service.dart';
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
  final List<List<Recordatorio>> programados = [];
  int cancelaciones = 0;

  @override
  Future<void> programar(List<Recordatorio> recordatorios) async =>
      programados.add(recordatorios);

  @override
  Future<void> cancelarTodo() async => cancelaciones++;
}

/// El portal, con próximos turnos y turnos libres programables.
///
/// Contesta lo que la prueba le pone —como la API, que es la que calcula
/// los turnos— y anota cada consulta para comprobar qué se pidió y cuántas
/// veces.
class PortalFalso implements PortalService {
  /// `medicos` de `/portal/proximos-turnos`, con su `proximo`.
  List<MedicoPortal> medicosDisponibles;

  /// `especialidades` de `/portal/proximos-turnos`.
  List<EspecialidadDisponible> especialidadesDisponibles;

  /// Los turnos libres de `/portal/turnos/:doctorId` por médico y modalidad.
  List<Turno> Function(String doctorId, TipoCita modalidad) turnosDe;

  /// Las citas que ya tiene cada dependiente (`pacienteId`): la API quita
  /// los turnos que empiezan a esa hora.
  Map<String, List<DateTime>> citasDelPaciente = {};

  /// Los que la API suma al reprogramar esa cita (`excluirCita`): su propio
  /// horario y los de al lado.
  List<Turno> Function(String citaId) liberadosAlExcluir = (_) => const [];

  /// La `duracion` de la respuesta de turnos; sin ella, la del primero.
  int? duracionTurnos;

  /// Si están puestos, esas llamadas fallan con este error.
  Object? errorEnProximos;
  Object? errorEnTurnos;
  Object? errorAlAgendar;
  Object? errorAlReprogramar;

  final List<NuevaCita> agendadas = [];
  final List<String> reprogramadas = [];
  final List<String> canceladas = [];

  /// Cada consulta de próximos turnos, con sus filtros y el paciente.
  final List<
    ({
      String? especialidad,
      String? ciudad,
      TipoCita? modalidad,
      String? pacienteId,
    })
  >
  consultasDeProximos = [];

  /// Cada consulta de turnos: `doctorId/MODALIDAD`.
  final List<String> consultasDeTurnos = [];

  /// El `excluirCita` de cada consulta de turnos, en el mismo orden.
  final List<String?> citasExcluidas = [];

  /// El `pacienteId` de cada consulta de turnos, en el mismo orden.
  final List<String?> pacientesDeTurnos = [];

  PortalFalso({
    this.medicosDisponibles = const [],
    this.especialidadesDisponibles = const [],
    List<Turno> Function(String, TipoCita)? turnosDe,
  }) : turnosDe = turnosDe ?? ((_, _) => const []);

  @override
  Future<ProximosTurnos> proximosTurnos({
    String? especialidad,
    String? ciudad,
    TipoCita? modalidad,
    String? pacienteId,
  }) async {
    consultasDeProximos.add((
      especialidad: especialidad,
      ciudad: ciudad,
      modalidad: modalidad,
      pacienteId: pacienteId,
    ));

    final error = errorEnProximos;
    if (error != null) throw error;

    return ProximosTurnos(
      especialidades: especialidadesDisponibles,
      medicos: medicosDisponibles,
    );
  }

  @override
  Future<TurnosMedico> turnos(
    String doctorId,
    TipoCita modalidad, {
    DateTime? desde,
    DateTime? hasta,
    String? excluirCita,
    String? pacienteId,
  }) async {
    consultasDeTurnos.add('$doctorId/${modalidad.codigo}');
    citasExcluidas.add(excluirCita);
    pacientesDeTurnos.add(pacienteId);

    final error = errorEnTurnos;
    if (error != null) throw error;

    final ocupadas = citasDelPaciente[pacienteId] ?? const [];
    final turnos = [
      ...turnosDe(doctorId, modalidad),
      if (excluirCita != null) ...liberadosAlExcluir(excluirCita),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    turnos.removeWhere((t) => ocupadas.contains(t.inicio));

    return TurnosMedico(
      doctorId: doctorId,
      modalidad: modalidad,
      duracion:
          duracionTurnos ??
          (turnos.isEmpty
              ? 30
              : turnos.first.fin.difference(turnos.first.inicio).inMinutes),
      turnos: turnos,
      pacienteId: pacienteId,
    );
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
    final error = errorAlReprogramar;
    if (error != null) throw error;

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

/// Una caché en memoria, reutilizando la de la aplicación.
CacheLocal cacheDePrueba() => CacheEnMemoria();
