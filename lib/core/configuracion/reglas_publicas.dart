// lib/core/configuracion/reglas_publicas.dart

part of 'config_publica.dart';

// Las secciones de reglas de la configuración pública: agenda,
// telemedicina, archivos, seguridad, general y clínico. Viven aparte para
// que ningún archivo crezca demasiado; comparten el lector de
// `config_publica.dart`.

/// `agenda`: citas, recordatorios y rejilla de horarios.
class ReglasAgenda extends Equatable {
  final int horasMinimasCambio;

  final bool recordatoriosActivos;
  final bool recordatorio24h;
  final bool recordatorio1h;
  final bool recordatorioInicio;

  /// Minutos por modalidad cuando el médico no configuró los suyos.
  final int duracionPresencial;
  final int duracionTelemedicina;
  final int duracionAsincrona;

  final int pasoMinutos;
  final int minutosAnticipacionReserva;
  final int diasHorizonteReserva;

  /// «HH:mm»: desde cuándo un horario cuenta como de la tarde o de la noche.
  final String horaInicioTarde;
  final String horaInicioNoche;

  const ReglasAgenda({
    required this.horasMinimasCambio,
    required this.recordatoriosActivos,
    required this.recordatorio24h,
    required this.recordatorio1h,
    required this.recordatorioInicio,
    required this.duracionPresencial,
    required this.duracionTelemedicina,
    required this.duracionAsincrona,
    required this.pasoMinutos,
    required this.minutosAnticipacionReserva,
    required this.diasHorizonteReserva,
    required this.horaInicioTarde,
    required this.horaInicioNoche,
  });

  factory ReglasAgenda._leer(_Lector l) => ReglasAgenda(
    horasMinimasCambio: l.entero('horasMinimasCambio'),
    recordatoriosActivos: l.booleano('recordatoriosActivos'),
    recordatorio24h: l.booleano('recordatorio24h'),
    recordatorio1h: l.booleano('recordatorio1h'),
    recordatorioInicio: l.booleano('recordatorioInicio'),
    duracionPresencial: l.entero('duracionPresencial', minimo: 1),
    duracionTelemedicina: l.entero('duracionTelemedicina', minimo: 1),
    duracionAsincrona: l.entero('duracionAsincrona', minimo: 1),
    pasoMinutos: l.entero('pasoMinutos', minimo: 1),
    minutosAnticipacionReserva: l.entero('minutosAnticipacionReserva'),
    diasHorizonteReserva: l.entero('diasHorizonteReserva', minimo: 1),
    horaInicioTarde: l.hora('horaInicioTarde'),
    horaInicioNoche: l.hora('horaInicioNoche'),
  );

  @override
  List<Object?> get props => [
    horasMinimasCambio,
    recordatoriosActivos,
    recordatorio24h,
    recordatorio1h,
    recordatorioInicio,
    duracionPresencial,
    duracionTelemedicina,
    duracionAsincrona,
    pasoMinutos,
    minutosAnticipacionReserva,
    diasHorizonteReserva,
    horaInicioTarde,
    horaInicioNoche,
  ];
}

/// `telemedicina`: la sala de video y las consultas en línea.
class ReglasTelemedicina extends Equatable {
  /// Cuántos minutos antes del inicio abre la sala y cuántos después del fin
  /// la cierra.
  final int minutosAntes;
  final int minutosDespues;

  final int horasRespuesta;
  final int diasSeguimiento;
  final int maxArchivosConsulta;

  /// Mediciones del paciente («Mis signos vitales») y el escáner
  /// experimental con su duración (20–60 s). Son opcionales porque un
  /// servidor anterior no los manda: sin ellos el módulo no se ofrece.
  final bool medicionesPacienteActiva;
  final bool escanerCamaraActivo;
  final int? escanerSegundos;

  /// El modo dedo del escáner (la yema sobre la cámara trasera con el
  /// flash). Opcional y apagado por defecto: sin él no hay selector de
  /// modo y se mide directo con el rostro.
  final bool escanerDedoActivo;

  const ReglasTelemedicina({
    required this.minutosAntes,
    required this.minutosDespues,
    required this.horasRespuesta,
    required this.diasSeguimiento,
    required this.maxArchivosConsulta,
    this.medicionesPacienteActiva = false,
    this.escanerCamaraActivo = false,
    this.escanerSegundos,
    this.escanerDedoActivo = false,
  });

  bool get escanerDisponible =>
      medicionesPacienteActiva &&
      escanerCamaraActivo &&
      escanerSegundos != null;

  factory ReglasTelemedicina._leer(_Lector l) => ReglasTelemedicina(
    minutosAntes: l.entero('minutosAntes'),
    minutosDespues: l.entero('minutosDespues'),
    horasRespuesta: l.entero('horasRespuesta', minimo: 1),
    diasSeguimiento: l.entero('diasSeguimiento'),
    maxArchivosConsulta: l.entero('maxArchivosConsulta'),
    medicionesPacienteActiva:
        l.booleanoOpcional('medicionesPacienteActiva') ?? false,
    escanerCamaraActivo: l.booleanoOpcional('escanerCamaraActivo') ?? false,
    escanerDedoActivo: l.booleanoOpcional('escanerDedoActivo') ?? false,
    escanerSegundos: l.enteroOpcional(
      'escanerSegundos',
      minimo: 20,
      maximo: 60,
    ),
  );

  @override
  List<Object?> get props => [
    minutosAntes,
    minutosDespues,
    horasRespuesta,
    diasSeguimiento,
    maxArchivosConsulta,
    medicionesPacienteActiva,
    escanerCamaraActivo,
    escanerSegundos,
    escanerDedoActivo,
  ];
}

/// `archivos`: el tope de cada archivo que se sube y los tipos que la
/// clínica acepta.
class ReglasArchivos extends Equatable {
  final int tamanoMaximoMb;

  /// Tipos MIME aceptados (`application/pdf`, `image/jpeg`…), elegidos por
  /// el administrador entre los que el servidor sabe verificar por su
  /// contenido.
  final List<String> tipos;

  const ReglasArchivos({required this.tamanoMaximoMb, required this.tipos});

  /// El tope en bytes, como lo mide el servidor (1 MB = 1024 × 1024).
  int get tamanoMaximoBytes => tamanoMaximoMb * 1024 * 1024;

  factory ReglasArchivos._leer(_Lector l) => ReglasArchivos(
    tamanoMaximoMb: l.entero('tamanoMaximoMb', minimo: 1),
    tipos: [for (final t in l.textos('tipos')) t.toLowerCase()],
  );

  @override
  List<Object?> get props => [tamanoMaximoMb, tipos];
}

/// `seguridad`: contraseñas, bloqueos y códigos.
class ReglasSeguridad extends Equatable {
  final int passwordMinimo;
  final int bloqueoMinutos;
  final int otpMinutos;

  /// Cuántos dígitos tiene el código de verificación en dos pasos.
  final int otpDigitos;
  final int resetMinutos;
  final int reenvioSegundos;

  const ReglasSeguridad({
    required this.passwordMinimo,
    required this.bloqueoMinutos,
    required this.otpMinutos,
    required this.otpDigitos,
    required this.resetMinutos,
    required this.reenvioSegundos,
  });

  factory ReglasSeguridad._leer(_Lector l) => ReglasSeguridad(
    passwordMinimo: l.entero('passwordMinimo', minimo: 1),
    bloqueoMinutos: l.entero('bloqueoMinutos'),
    otpMinutos: l.entero('otpMinutos'),
    otpDigitos: l.entero('otpDigitos', minimo: 1),
    resetMinutos: l.entero('resetMinutos'),
    reenvioSegundos: l.entero('reenvioSegundos'),
  );

  @override
  List<Object?> get props => [
    passwordMinimo,
    bloqueoMinutos,
    otpMinutos,
    otpDigitos,
    resetMinutos,
    reenvioSegundos,
  ];
}

/// `general`: lo que queda de la sección general que la aplicación usa.
class ReglasGenerales extends Equatable {
  /// Si la cédula ecuatoriana se valida con su dígito verificador (módulo
  /// 10). Apagado, basta con que tenga diez dígitos.
  final bool validarCedula;

  /// Los días que tiene la clínica para responder una solicitud ARCO (el
  /// servidor calcula con ellos el `plazoVence` de cada una).
  final int arcoPlazoDias;

  /// Hasta cuántos días después de una cita atendida se puede responder su
  /// encuesta.
  final int encuestasDiasVentana;

  /// Horas de respuesta de soporte por severidad del ticket
  /// (`{CRITICA: 4, ALTA: 24, …}`), las mismas con que el servidor calcula
  /// el vencimiento de cada ticket.
  final Map<String, int> soporteHorasSla;

  /// A cuántas horas del vencimiento un ticket abierto «vence pronto».
  final int soporteHorasAviso;

  const ReglasGenerales({
    required this.validarCedula,
    required this.arcoPlazoDias,
    required this.encuestasDiasVentana,
    required this.soporteHorasSla,
    required this.soporteHorasAviso,
  });

  factory ReglasGenerales._leer(_Lector l) => ReglasGenerales(
    validarCedula: l.booleano('validarCedula'),
    arcoPlazoDias: l.entero('arcoPlazoDias', minimo: 1),
    encuestasDiasVentana: l.entero('encuestasDiasVentana', minimo: 1),
    soporteHorasSla: l.enterosPorClave('soporteHorasSla', minimo: 1),
    soporteHorasAviso: l.entero('soporteHorasAviso', minimo: 1),
  );

  @override
  List<Object?> get props => [
    validarCedula,
    arcoPlazoDias,
    encuestasDiasVentana,
    soporteHorasSla,
    soporteHorasAviso,
  ];
}

/// `clinico`: las reglas clínicas de apoyo que la aplicación usa.
class ReglasClinicas extends Equatable {
  /// Los días que suma la regla de Naegele a la fecha de la última
  /// menstruación para la fecha probable de parto (Mi salud).
  final int diasGestacion;

  const ReglasClinicas({required this.diasGestacion});

  factory ReglasClinicas._leer(_Lector l) =>
      ReglasClinicas(diasGestacion: l.entero('diasGestacion', minimo: 1));

  @override
  List<Object?> get props => [diasGestacion];
}
