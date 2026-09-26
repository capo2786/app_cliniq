import 'package:dio/dio.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../citas/data/models/cita.dart';
import '../dominio/huecos.dart';
import 'models/medico_portal.dart';

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

/// El portal del paciente: médicos, lo ocupado de su agenda, agendar,
/// reprogramar y cancelar.
///
/// Usa las rutas propias del portal y no las del personal: el paciente no
/// puede ver la agenda de un médico —tiene datos de otros pacientes—, solo
/// los intervalos ocupados.
class PortalService {
  final Dio _dio;

  PortalService(this._dio);

  /// `GET /portal/medicos`, con filtros opcionales.
  Future<List<MedicoPortal>> medicos({
    String? especialidad,
    String? ciudad,
    TipoCita? modalidad,
  }) async {
    final respuesta = await _dio.get<dynamic>(
      '/portal/medicos',
      queryParameters: {
        if (especialidad != null && especialidad.isNotEmpty)
          'especialidad': especialidad,
        if (ciudad != null && ciudad.isNotEmpty) 'ciudad': ciudad,
        if (modalidad != null) 'modalidad': modalidad.codigo,
      },
    );

    final datos = respuesta.data;
    if (datos is! List) return const [];

    return [
      for (final m in datos)
        if (m is Map) MedicoPortal.desdeJson(m),
    ].where((m) => m.uid.isNotEmpty).toList();
  }

  /// `GET /portal/disponibilidad/:doctorId`: lo ocupado entre dos días
  /// (inclusive), como intervalos en hora local. Máximo 62 días.
  Future<List<IntervaloOcupado>> ocupados(
    String doctorId,
    DateTime desde,
    DateTime hasta,
  ) async {
    final respuesta = await _dio.get<dynamic>(
      '/portal/disponibilidad/$doctorId',
      queryParameters: {'desde': fechaIso(desde), 'hasta': fechaIso(hasta)},
    );

    final datos = respuesta.data;
    if (datos is! List) return const [];

    final intervalos = <IntervaloOcupado>[];
    for (var i = 0; i < datos.length; i++) {
      final x = datos[i];
      if (x is! Map) continue;

      final inicio = leerFechaLocal(x['start']);
      final fin = leerFechaLocal(x['end']);
      if (inicio == null || fin == null) continue;

      intervalos.add(
        IntervaloOcupado(id: 'ocupado-$i', inicio: inicio, fin: fin),
      );
    }

    return intervalos;
  }

  /// `POST /portal/citas`.
  Future<Cita> agendar(NuevaCita cita) async {
    final respuesta = await _dio.post<dynamic>(
      '/portal/citas',
      data: cita.aJson(),
    );

    return Cita.desdeJson(respuesta.data as Map);
  }

  /// `PATCH /portal/citas/:id/reprogramar`. Exige 12 horas de anticipación.
  Future<Cita> reprogramar(String id, DateTime inicio, DateTime fin) async {
    final respuesta = await _dio.patch<dynamic>(
      '/portal/citas/$id/reprogramar',
      data: {'start': aTextoLocal(inicio), 'end': aTextoLocal(fin)},
    );

    return Cita.desdeJson(respuesta.data as Map);
  }

  /// `PATCH /portal/citas/:id/cancelar`. Exige 12 horas de anticipación.
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
