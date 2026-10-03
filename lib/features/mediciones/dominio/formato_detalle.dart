// lib/features/mediciones/dominio/formato_detalle.dart

/// El formato `detalle` (versión 1) del «Detalle de la medición»: lo que se
/// guarda con el pulso medido con la cámara y lo que devuelve
/// `GET /portal/mediciones/:id`. Lo comparten la aplicación y el API (ver
/// `contratos/detalle-medicion.md`, punto 1): **solo números**, nunca
/// imágenes ni la serie cruda de la cámara.
///
/// - [detalleAJson] lo escribe dentro de los límites del formato (y de los
///   que agregó el API) y redondeado: 3 decimales en la onda, la
///   respiración y la potencia del espectro; 2 en la calidad; 1 en lo
///   demás. Antes de enviarlo, `validacion_detalle.dart` lo comprueba.
/// - [detalleDesdeJson] es tolerante: si algo no cuadra, devuelve `null` en
///   vez de lanzar. Las claves desconocidas se ignoran.
library;

import 'detalle_medicion.dart';
import 'procesamiento_ppg.dart';

/// La versión del formato.
const int versionDetalle = 1;

/// El tamaño máximo del JSON del detalle que acepta el servidor.
const int maximoBytesDetalle = 48 * 1024;

const int _maxOnda = 900;
const int _maxLatidosOnda = 150;
const int _maxFc = 150;
const int _maxIntervalos = 400;
const int _maxEspectro = 256;
const int _maxRespiracion = 900;
const int _maxLatidos = 400;

double _r1(double x) => (x * 10).round() / 10;
double _r2(double x) => (x * 100).round() / 100;
double _r3(double x) => (x * 1000).round() / 1000;

double _entre(double x, double minimo, double maximo) =>
    x.isFinite ? x.clamp(minimo, maximo).toDouble() : minimo;

/// Los últimos [maximo] de una lista.
List<T> _ultimos<T>(List<T> x, int maximo) =>
    x.length > maximo ? x.sublist(x.length - maximo) : x;

/// Un segundo de la medición que el servidor acepta (0 a 600).
bool _segundoPosible(double s) => s >= 0 && s <= 600;

/// Las métricas, si están en los rangos que acepta el servidor; si no, no
/// se mandan (y la variabilidad no se enseña).
MetricasRr? _metricasPosibles(MetricasRr? m) {
  if (m == null) return null;
  bool entre(double x, double minimo, double maximo) =>
      x.isFinite && x >= minimo && x <= maximo;
  final posibles =
      m.intervalos >= 0 &&
      m.intervalos <= _maxIntervalos &&
      m.corregidos >= 0 &&
      [m.medio, m.minimo, m.maximo].every((x) => entre(x, 250, 2000)) &&
      [m.sdnn, m.rmssd, m.sd1, m.sd2].every((x) => entre(x, 0, 2000)) &&
      entre(m.pnn50, 0, 100);
  return posibles ? m : null;
}

/// El detalle en el formato v1, listo para enviar.
Map<String, dynamic> detalleAJson(DetalleMedicion d) {
  final onda = _ultimos(d.onda, _maxOnda);
  final corte = d.onda.length - onda.length;
  final latidosEnOnda = _ultimos([
    for (final i in d.latidosEnOnda)
      if (i - corte >= 0 && i - corte < onda.length) i - corte,
  ], _maxLatidosOnda);

  final fc = _ultimos([
    for (final p in d.fcPorSegundo)
      if (_segundoPosible(p.segundo) && p.fc >= 30 && p.fc <= 220) p,
  ], _maxFc);
  final intervalos = _ultimos([
    for (final i in d.intervalos)
      if (_segundoPosible(i.segundo) && i.ms >= 250 && i.ms <= 2000) i,
  ], _maxIntervalos);
  final espectro = [
    for (final p in d.espectro)
      if (p.lpm >= 30 && p.lpm <= 240 && p.potencia.isFinite) p,
  ].take(_maxEspectro).toList();
  final respiracion = _ultimos(d.respiracion, _maxRespiracion);
  final m = _metricasPosibles(d.metricas);
  final pico = d.picoLpm;

  return {
    'v': versionDetalle,
    'duracion': _r1(_entre(d.duracion, 5, 120)),
    'calidad': _r2(_entre(d.calidad, 0, 1)),
    'latidos': d.latidos.clamp(0, _maxLatidos),
    'onda': {
      'fs': _r1(_entre(d.fs, 5, 60)),
      'valores': [for (final v in onda) _r3(_entre(v, -1, 1))],
      'latidos': latidosEnOnda,
    },
    'fc': {
      's': [for (final p in fc) _r1(p.segundo)],
      'lpm': [for (final p in fc) _r1(p.fc)],
    },
    'intervalos': {
      's': [for (final i in intervalos) _r1(i.segundo)],
      'ms': [for (final i in intervalos) _r1(i.ms)],
    },
    'metricas': m == null
        ? null
        : {
            'intervalos': m.intervalos,
            'medio': _r1(m.medio),
            'minimo': _r1(m.minimo),
            'maximo': _r1(m.maximo),
            'sdnn': _r1(m.sdnn),
            'rmssd': _r1(m.rmssd),
            'pnn50': _r1(m.pnn50),
            'sd1': _r1(m.sd1),
            'sd2': _r1(m.sd2),
            'corregidos': m.corregidos,
          },
    'vfcValida': d.vfcValida && m != null,
    'espectro': {
      'lpm': [for (final p in espectro) _r1(p.lpm)],
      'potencia': [for (final p in espectro) _r3(_entre(p.potencia, 0, 1))],
    },
    if (pico != null && pico >= 30 && pico <= 240) 'picoLpm': _r1(pico),
    if (respiracion.isNotEmpty)
      'respiracion': {
        'fs': _r1(_entre(d.fsRespiracion, 1, 30)),
        'valores': [for (final v in respiracion) _r3(_entre(v, -1, 1))],
      },
  };
}

/// Un número finito, o `null`.
double? _numero(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// Un entero (también `37.0`), o `null`.
int? _entero(Object? v) =>
    v is num && v.isFinite && v == v.roundToDouble() ? v.toInt() : null;

/// Una lista de números finitos, o `null` si algo no lo es.
List<double>? _numeros(Object? v) {
  if (v is! List) return null;
  final salida = <double>[];
  for (final e in v) {
    final n = _numero(e);
    if (n == null) return null;
    salida.add(n);
  }
  return salida;
}

/// Dos listas de números del mismo largo, o `null`.
(List<double>, List<double>)? _pares(Object? v, String a, String b) {
  if (v is! Map) return null;
  final x = _numeros(v[a]);
  final y = _numeros(v[b]);
  if (x == null || y == null || x.length != y.length) return null;
  return (x, y);
}

/// Las métricas, o `null` si alguna no está o no es un número.
MetricasRr? _metricas(Map<dynamic, dynamic> m) {
  final intervalos = _entero(m['intervalos']);
  final corregidos = _entero(m['corregidos']);
  final valores = [
    for (final clave in const [
      'medio',
      'minimo',
      'maximo',
      'sdnn',
      'rmssd',
      'pnn50',
      'sd1',
      'sd2',
    ])
      _numero(m[clave]),
  ];
  if (intervalos == null ||
      intervalos < 0 ||
      corregidos == null ||
      corregidos < 0 ||
      valores.contains(null)) {
    return null;
  }
  return MetricasRr(
    intervalos: intervalos,
    medio: valores[0]!,
    minimo: valores[1]!,
    maximo: valores[2]!,
    sdnn: valores[3]!,
    rmssd: valores[4]!,
    pnn50: valores[5]!,
    sd1: valores[6]!,
    sd2: valores[7]!,
    corregidos: corregidos,
  );
}

/// Lee un detalle v1; `null` si no es uno o si algo no cuadra.
DetalleMedicion? detalleDesdeJson(Object? json) {
  try {
    return _leer(json);
  } catch (_) {
    return null;
  }
}

DetalleMedicion? _leer(Object? json) {
  if (json is! Map || _entero(json['v']) != versionDetalle) return null;

  final duracion = _numero(json['duracion']);
  final calidad = _numero(json['calidad']);
  final latidos = _entero(json['latidos']);
  if (duracion == null || duracion <= 0 || calidad == null) return null;
  if (latidos == null || latidos < 0) return null;

  final onda = json['onda'];
  if (onda is! Map) return null;
  final fs = _numero(onda['fs']);
  final valores = _numeros(onda['valores']);
  final enOnda = _numeros(onda['latidos']);
  if (fs == null || fs <= 0 || valores == null || enOnda == null) return null;
  final indices = [for (final i in enOnda) _entero(i)];
  if (indices.any((i) => i == null || i < 0 || i >= valores.length)) {
    return null;
  }

  final fc = _pares(json['fc'], 's', 'lpm');
  final rr = _pares(json['intervalos'], 's', 'ms');
  final espectro = _pares(json['espectro'], 'lpm', 'potencia');
  if (fc == null || rr == null || espectro == null) return null;

  final metricasJson = json['metricas'];
  final metricas = metricasJson is Map ? _metricas(metricasJson) : null;
  if (metricasJson != null && metricas == null) return null;

  final picoJson = json['picoLpm'];
  final pico = _numero(picoJson);
  if (picoJson != null && pico == null) return null;

  final respiracionJson = json['respiracion'];
  var respiracion = const <double>[];
  var fsRespiracion = 5.0;
  if (respiracionJson != null) {
    if (respiracionJson is! Map) return null;
    final f = _numero(respiracionJson['fs']);
    final v = _numeros(respiracionJson['valores']);
    if (f == null || f <= 0 || v == null) return null;
    respiracion = v;
    fsRespiracion = f;
  }

  return DetalleMedicion(
    duracion: duracion,
    calidad: calidad.clamp(0, 1).toDouble(),
    onda: valores,
    latidosEnOnda: [for (final i in indices) i!],
    fs: fs,
    latidos: latidos,
    fcPorSegundo: [
      for (var i = 0; i < fc.$1.length; i++) (segundo: fc.$1[i], fc: fc.$2[i]),
    ],
    intervalos: [
      for (var i = 0; i < rr.$1.length; i++) (segundo: rr.$1[i], ms: rr.$2[i]),
    ],
    metricas: metricas,
    vfcValida: json['vfcValida'] == true && metricas != null,
    espectro: [
      for (var i = 0; i < espectro.$1.length; i++)
        (lpm: espectro.$1[i], potencia: espectro.$2[i]),
    ],
    picoLpm: pico,
    respiracion: respiracion,
    fsRespiracion: fsRespiracion,
  );
}
