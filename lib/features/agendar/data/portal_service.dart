import 'package:dio/dio.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../citas/data/models/cita.dart';
import 'models/turnos.dart';

/// Lo que se manda para agendar una cita desde el portal.
class NuevaCita {
  final String doctorId;
  final DateTime inicio;
  final DateTime fin;
  final TipoCita tipo;
  final String motivo;

  /// Solo si la cita es para un dependiente; sin él, es para el titular.
  final String? pacienteId;

  const NuevaCita({
    required this.doctorId,
    required this.inicio,
    required this.fin,
    required this.tipo,
    required this.motivo,
    this.pacienteId,
  });

  Map<String, dynamic> aJson() => {
    'doctorId': doctorId,
    'start': aTextoLocal(inicio),
    'end': aTextoLocal(fin),
    'type': tipo.codigo,
    'reason': motivo.trim(),
    if (pacienteId != null && pacienteId!.isNotEmpty) 'pacienteId': pacienteId,
  };
}

/// El portal del paciente: los turnos libres, agendar, reprogramar y
/// cancelar.
///
/// Usa las rutas propias del portal y no las del personal: el paciente no
/// puede ver la agenda de un médico —tiene datos de otros pacientes—, solo
/// los turnos que le puede tomar. Esos turnos los calcula la API con las
/// mismas reglas con que valida la reserva; la aplicación no calcula nada.
class PortalService {
  final Dio _dio;

  PortalService(this._dio);

  /// `GET /portal/proximos-turnos`: las especialidades con cuántos médicos
  /// tienen turnos libres y el primero de ellos, y esos médicos con su
  /// próximo turno. Los filtros son opcionales.
  Future<ProximosTurnos> proximosTurnos({
    String? especialidad,
    String? ciudad,
    TipoCita? modalidad,
  }) async {
    final respuesta = await _dio.get<dynamic>(
      '/portal/proximos-turnos',
      queryParameters: {
        if (especialidad != null && especialidad.isNotEmpty)
          'especialidad': especialidad,
        if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
        if (modalidad != null) 'modalidad': modalidad.codigo,
      },
    );

    final datos = respuesta.data;
    if (datos is! Map) {
      throw const FormatException('Respuesta de próximos turnos ilegible');
    }

    return ProximosTurnos.desdeJson(datos);
  }

  /// `GET /portal/turnos/:doctorId`: los turnos libres del médico en esa
  /// modalidad. Sin [desde] ni [hasta], la API devuelve de hoy al horizonte
  /// de reserva de la clínica.
  ///
  /// Al reprogramar, [excluirCita] es la cita que se mueve: su propio
  /// horario y los de al lado cuentan como libres.
  Future<TurnosMedico> turnos(
    String doctorId,
    TipoCita modalidad, {
    DateTime? desde,
    DateTime? hasta,
    String? excluirCita,
  }) async {
    final respuesta = await _dio.get<dynamic>(
      '/portal/turnos/$doctorId',
      queryParameters: {
        'modalidad': modalidad.codigo,
        if (desde != null) 'desde': fechaIso(desde),
        if (hasta != null) 'hasta': fechaIso(hasta),
        if (excluirCita != null && excluirCita.isNotEmpty)
          'excluirCita': excluirCita,
      },
    );

    final datos = respuesta.data;
    if (datos is! Map) {
      throw const FormatException('Respuesta de turnos ilegible');
    }

    return TurnosMedico.desdeJson(
      datos,
      doctorId: doctorId,
      modalidad: modalidad,
    );
  }

  /// `POST /portal/citas`.
  Future<Cita> agendar(NuevaCita cita) async {
    final respuesta = await _dio.post<dynamic>(
      '/portal/citas',
      data: cita.aJson(),
    );

    return Cita.desdeJson(respuesta.data as Map);
  }

  /// `PATCH /portal/citas/:id/reprogramar`. Exige las horas de anticipación
  /// de la clínica (`agenda.horasMinimasCambio`).
  Future<Cita> reprogramar(String id, DateTime inicio, DateTime fin) async {
    final respuesta = await _dio.patch<dynamic>(
      '/portal/citas/$id/reprogramar',
      data: {'start': aTextoLocal(inicio), 'end': aTextoLocal(fin)},
    );

    return Cita.desdeJson(respuesta.data as Map);
  }

  /// `PATCH /portal/citas/:id/cancelar`. Exige las horas de anticipación de
  /// la clínica (`agenda.horasMinimasCambio`).
  Future<Cita> cancelar(String id, String motivo, {String? detalle}) async {
    final respuesta = await _dio.patch<dynamic>(
      '/portal/citas/$id/cancelar',
      data: {
        'motivo': motivo,
        if (detalle != null && detalle.trim().isNotEmpty)
          'detalle': detalle.trim(),
      },
    );

    return Cita.desdeJson(respuesta.data as Map);
  }
}
