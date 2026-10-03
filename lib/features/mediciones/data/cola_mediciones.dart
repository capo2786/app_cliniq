// lib/features/mediciones/data/cola_mediciones.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import 'mediciones_service.dart';
import 'models/medicion.dart';

/// Un envío que todavía no llegó al servidor: las mediciones que la persona
/// registró sin red (hasta [MedicionesService.maximoPorEnvio]), para quién y
/// cuándo.
class EnvioPendiente extends Equatable {
  /// Identificador local, solo del teléfono.
  final String idLocal;

  /// El dependiente, o `null` si es del titular.
  final String? pacienteId;

  final List<MedicionNueva> mediciones;

  /// Cuándo se guardó en el teléfono.
  final DateTime creadoEn;

  /// Si el servidor lo rechazó al enviarlo (un valor fuera de rango, más de
  /// 30 días, la cámara apagada), su mensaje. Uno rechazado no se reintenta:
  /// la persona lo ve y lo descarta.
  final String? rechazo;

  const EnvioPendiente({
    required this.idLocal,
    required this.mediciones,
    required this.creadoEn,
    this.pacienteId,
    this.rechazo,
  });

  bool get rechazado => rechazo != null;

  EnvioPendiente conRechazo(String mensaje) => EnvioPendiente(
    idLocal: idLocal,
    pacienteId: pacienteId,
    mediciones: mediciones,
    creadoEn: creadoEn,
    rechazo: mensaje,
  );

  Map<String, dynamic> aJson() => {
    'idLocal': idLocal,
    'pacienteId': pacienteId,
    'mediciones': [for (final m in mediciones) m.aJson()],
    'creadoEn': aTextoInstante(creadoEn),
    'rechazo': rechazo,
  };

  static EnvioPendiente? desdeJson(Object? json) {
    if (json is! Map) return null;

    final id = json['idLocal']?.toString() ?? '';
    final creado = leerInstante(json['creadoEn']);
    final lista = json['mediciones'];
    if (id.isEmpty || creado == null || lista is! List) return null;

    final mediciones = [for (final m in lista) ?MedicionNueva.desdeJson(m)];
    if (mediciones.isEmpty) return null;

    final paciente = json['pacienteId']?.toString();
    final rechazo = json['rechazo']?.toString();
    return EnvioPendiente(
      idLocal: id,
      pacienteId: paciente == null || paciente.isEmpty ? null : paciente,
      mediciones: mediciones,
      creadoEn: creado,
      rechazo: rechazo == null || rechazo.isEmpty ? null : rechazo,
    );
  }

  @override
  List<Object?> get props => [
    idLocal,
    pacienteId,
    mediciones,
    creadoEn,
    rechazo,
  ];
}

/// Qué pasó con un registro.
sealed class ResultadoRegistro {
  const ResultadoRegistro();
}

/// Llegó al servidor.
class RegistroEnviado extends ResultadoRegistro {
  final List<Medicion> creadas;

  const RegistroEnviado(this.creadas);
}

/// No había red: quedó en el teléfono y se enviará al volver.
class RegistroPendiente extends ResultadoRegistro {
  final EnvioPendiente envio;

  const RegistroPendiente(this.envio);
}

/// Lo que dejó un intento de enviar lo pendiente.
class ResultadoSincronizacion {
  final int enviados;
  final int rechazados;
  final int quedan;

  const ResultadoSincronizacion({
    this.enviados = 0,
    this.rechazados = 0,
    this.quedan = 0,
  });
}

/// La cola sin red de las mediciones, en la caché cifrada (Hive).
///
/// Registrar primero intenta enviar; si no hay red, guarda el envío en el
/// teléfono (`mediciones-pendientes:<uid>`) y lo envía al volver la
/// conexión ([enviarPendientes]: al abrir la aplicación, al volver a ella,
/// al recuperar la red y al abrir «Mis signos vitales»). Lo pendiente son
/// números que la persona escribió o midió: se enseñan como «Pendiente de
/// enviar», nunca como guardados en la clínica, y nunca se inventa nada.
///
/// Si el servidor rechaza un envío (un 4xx: un valor fuera de rango, más de
/// 30 días, la cámara apagada por el administrador), queda marcado con su
/// mensaje y no se reintenta; la persona lo descarta. Un 5xx o la falta de
/// red lo dejan para la próxima. Como todo lo personal, se borra al cerrar
/// sesión.
class ColaMediciones {
  final CacheLocal _cache;
  final MedicionesService _servicio;
  final DateTime Function() _ahora;
  final math.Random _azar = math.Random();

  /// Cambia cada vez que cambia la cola: las pantallas lo escuchan para
  /// refrescarse cuando lo pendiente sale solo.
  final ValueNotifier<int> cambios = ValueNotifier(0);

  final Map<String, Future<ResultadoSincronizacion>> _enCurso = {};

  ColaMediciones(this._cache, this._servicio, {DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  String _clave(String uid) => 'mediciones-pendientes:$uid';

  String _nuevoId() =>
      '${_ahora().microsecondsSinceEpoch}-${_azar.nextInt(1 << 32)}';

  /// Lo pendiente de esa persona, del más antiguo al más nuevo.
  Future<List<EnvioPendiente>> pendientes(String uid) async {
    final datos = await _cache.leer(_clave(uid));
    if (datos is! List) return const [];

    return [for (final item in datos) ?EnvioPendiente.desdeJson(item)];
  }

  Future<void> _guardar(String uid, List<EnvioPendiente> lista) async {
    await _cache.guardar(_clave(uid), [for (final e in lista) e.aJson()]);
    cambios.value++;
  }

  /// Registra [mediciones]: las envía o, sin red, las deja en la cola. Un
  /// rechazo del servidor (400, 409…) se propaga: la persona tiene que
  /// verlo, y no tiene sentido guardar algo que el servidor no acepta.
  Future<ResultadoRegistro> registrar(
    String uid, {
    String? pacienteId,
    required List<MedicionNueva> mediciones,
  }) async {
    try {
      final creadas = await _servicio.enviar(
        pacienteId: pacienteId,
        mediciones: mediciones,
      );
      return RegistroEnviado(creadas);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final envio = EnvioPendiente(
        idLocal: _nuevoId(),
        pacienteId: pacienteId,
        mediciones: mediciones,
        creadoEn: _ahora().toUtc(),
      );
      await _guardar(uid, [...await pendientes(uid), envio]);
      return RegistroPendiente(envio);
    }
  }

  /// Quita un envío de la cola (el que el servidor rechazó, o uno que la
  /// persona ya no quiere enviar).
  Future<void> descartar(String uid, String idLocal) async {
    final lista = await pendientes(uid);
    await _guardar(uid, [
      for (final e in lista)
        if (e.idLocal != idLocal) e,
    ]);
  }

  /// Envía lo pendiente, del más antiguo al más nuevo. Si dos llamadas se
  /// cruzan (la red volvió justo al abrir la pantalla), comparten la misma.
  Future<ResultadoSincronizacion> enviarPendientes(String uid) {
    if (uid.isEmpty) return Future.value(const ResultadoSincronizacion());

    // El cierre no devuelve nada a propósito: si devolviera lo que quita
    // (este mismo envío), `whenComplete` se quedaría esperándose a sí mismo.
    return _enCurso[uid] ??= _enviar(uid).whenComplete(() {
      _enCurso.remove(uid);
    });
  }

  Future<ResultadoSincronizacion> _enviar(String uid) async {
    final lista = await pendientes(uid);
    if (lista.every((e) => e.rechazado)) {
      return ResultadoSincronizacion(quedan: lista.length);
    }

    final quedan = <EnvioPendiente>[];
    var enviados = 0;
    var rechazados = 0;
    var sinServidor = false;

    for (final envio in lista) {
      if (envio.rechazado || sinServidor) {
        quedan.add(envio);
        continue;
      }

      try {
        await _servicio.enviar(
          pacienteId: envio.pacienteId,
          mediciones: envio.mediciones,
        );
        enviados++;
      } catch (error) {
        final estado = estadoDe(error) ?? 0;
        if (estado >= 400 && estado < 500 && estado != 401) {
          rechazados++;
          quedan.add(
            envio.conRechazo(
              mensajeDeError(
                error,
                generico: 'La clínica no aceptó esta medición.',
              ),
            ),
          );
        } else {
          // Sin red, con el servidor caído o con la sesión vencida: se
          // queda todo para la próxima.
          sinServidor = true;
          quedan.add(envio);
        }
      }
    }

    if (enviados > 0 || rechazados > 0) await _guardar(uid, quedan);

    return ResultadoSincronizacion(
      enviados: enviados,
      rechazados: rechazados,
      quedan: quedan.length,
    );
  }
}
