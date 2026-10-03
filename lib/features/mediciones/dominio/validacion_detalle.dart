// lib/features/mediciones/dominio/validacion_detalle.dart

/// La validación del `detalle` (v1) antes de enviarlo o guardarlo en la
/// cola, con los mismos límites que aplica el servidor: los del punto 1 del
/// contrato y los que el API agregó (los segundos de `fc` e `intervalos`
/// entre 0 y 600, `picoLpm` entre 30 y 240, las métricas completas y en sus
/// rangos, ningún número como texto y 48 KB como máximo).
///
/// Si el servidor recibe un detalle que no cumple, rechaza con 400 la
/// medición entera; por eso la aplicación lo comprueba antes y, si no pasa,
/// manda la medición sin él: una medición nunca se pierde por su detalle.
///
/// Pura y probada (`test/formato_detalle_test.dart`).
library;

import 'dart:convert';

import 'formato_detalle.dart';

/// Un número finito (nunca un texto) entre [minimo] y [maximo].
bool _numeroEntre(Object? v, num minimo, num maximo) =>
    v is num && v.isFinite && v >= minimo && v <= maximo;

/// Un entero (sin decimales) entre [minimo] y [maximo].
bool _enteroEntre(Object? v, int minimo, int maximo) =>
    v is int && v >= minimo && v <= maximo;

/// Una lista de hasta [largo] números, cada uno entre [minimo] y [maximo].
bool _numerosEntre(Object? v, int largo, num minimo, num maximo) =>
    v is List &&
    v.length <= largo &&
    v.every((e) => _numeroEntre(e, minimo, maximo));

/// El primer campo que no cumple, o `null` si el detalle es válido.
String? problemaDelDetalle(Object? detalle) {
  if (detalle is! Map) return 'detalle';
  final d = detalle;

  if (d['v'] != versionDetalle) return 'v';
  if (!_numeroEntre(d['duracion'], 5, 120)) return 'duracion';
  if (!_numeroEntre(d['calidad'], 0, 1)) return 'calidad';
  if (!_enteroEntre(d['latidos'], 0, 400)) return 'latidos';

  final onda = d['onda'];
  if (onda is! Map) return 'onda';
  if (!_numeroEntre(onda['fs'], 5, 60)) return 'onda.fs';
  final valores = onda['valores'];
  if (!_numerosEntre(valores, 900, -1, 1)) return 'onda.valores';
  final latidos = onda['latidos'];
  if (latidos is! List ||
      latidos.length > 150 ||
      !latidos.every((i) => _enteroEntre(i, 0, (valores as List).length - 1))) {
    return 'onda.latidos';
  }

  final pares = <(String, String, String, int, num, num, num, num)>[
    ('fc', 's', 'lpm', 150, 0, 600, 30, 220),
    ('intervalos', 's', 'ms', 400, 0, 600, 250, 2000),
    ('espectro', 'lpm', 'potencia', 256, 30, 240, 0, 1),
  ];
  for (final (clave, a, b, largo, minA, maxA, minB, maxB) in pares) {
    final par = d[clave];
    if (par is! Map) return clave;
    if (!_numerosEntre(par[a], largo, minA, maxA)) return '$clave.$a';
    if (!_numerosEntre(par[b], largo, minB, maxB)) return '$clave.$b';
    if ((par[a] as List).length != (par[b] as List).length) return clave;
  }

  final metricas = d['metricas'];
  if (metricas != null) {
    if (metricas is! Map) return 'metricas';
    final problema = _problemaDeMetricas(metricas);
    if (problema != null) return 'metricas.$problema';
  }
  if (d['vfcValida'] is! bool) return 'vfcValida';

  if (d.containsKey('picoLpm') && !_numeroEntre(d['picoLpm'], 30, 240)) {
    return 'picoLpm';
  }

  final respiracion = d['respiracion'];
  if (respiracion != null) {
    if (respiracion is! Map) return 'respiracion';
    if (!_numeroEntre(respiracion['fs'], 1, 30)) return 'respiracion.fs';
    if (!_numerosEntre(respiracion['valores'], 900, -1, 1)) {
      return 'respiracion.valores';
    }
  }

  try {
    if (utf8.encode(jsonEncode(d)).length > maximoBytesDetalle) {
      return 'tamaño';
    }
  } catch (_) {
    return 'detalle';
  }
  return null;
}

/// Las métricas, si vienen, con todos sus campos y en sus rangos.
String? _problemaDeMetricas(Map<dynamic, dynamic> m) {
  if (!_enteroEntre(m['intervalos'], 0, 400)) return 'intervalos';
  for (final clave in const ['medio', 'minimo', 'maximo']) {
    if (!_numeroEntre(m[clave], 250, 2000)) return clave;
  }
  for (final clave in const ['sdnn', 'rmssd', 'sd1', 'sd2']) {
    if (!_numeroEntre(m[clave], 0, 2000)) return clave;
  }
  if (!_numeroEntre(m['pnn50'], 0, 100)) return 'pnn50';
  if (m['corregidos'] is! int || (m['corregidos'] as int) < 0) {
    return 'corregidos';
  }
  return null;
}

/// El detalle cumple todos los límites del servidor.
bool detalleValido(Object? detalle) => problemaDelDetalle(detalle) == null;
