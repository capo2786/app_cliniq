import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// Por qué no se pudo hablar con el servidor.
///
/// Son cuatro cosas distintas y cada una se arregla de otra manera, así que
/// hay que nombrarlas en vez de decir siempre «revisa tu conexión».
enum MotivoDeRed {
  /// Hay servidor y responde. Todo bien.
  conectado,

  /// El teléfono no llegó a ninguna parte: sin cobertura, en modo avión.
  sinRed,

  /// Hay red —el wifi de la sala de espera, el del café— pero no sale a
  /// Internet: devuelve su página de «acepta las condiciones».
  sinSalida,

  /// Se llegó al servidor y contestó mal: está caído o en mantenimiento.
  servidorCaido,
}

/// Cómo está la red ahora mismo, con el motivo y algo que decirle a la gente.
@immutable
class EstadoDeLaRed {
  final MotivoDeRed motivo;

  const EstadoDeLaRed(this.motivo);

  bool get hayInternet => motivo == MotivoDeRed.conectado;

  /// Lo que se le dice a la persona. Habla de lo que puede hacer, no de HTTP.
  String get explicacion => switch (motivo) {
    MotivoDeRed.conectado => 'Hay conexión con la clínica.',
    MotivoDeRed.sinRed =>
      'El teléfono no tiene conexión. Puedes ver tus citas guardadas; '
          'para agendar o cambiar algo necesitas Internet.',
    MotivoDeRed.sinSalida =>
      'Estás conectado a una red que no llega a Internet —suele pasar con '
          'un wifi que pide aceptar condiciones en el navegador—. Prueba '
          'con tus datos móviles.',
    MotivoDeRed.servidorCaido =>
      'El servidor de la clínica no está respondiendo. No es tu teléfono: '
          'vuelve a intentarlo en unos minutos.',
  };

  @override
  bool operator ==(Object other) =>
      other is EstadoDeLaRed && other.motivo == motivo;

  @override
  int get hashCode => motivo.hashCode;
}

/// Comprueba si de verdad se puede hablar con el servidor, y lo recuerda.
///
/// Que el teléfono diga «wifi conectado» no significa nada: hay redes que
/// aceptan la conexión y después no dejan salir. Por eso se pregunta al
/// servidor de verdad, con una petición diminuta y un plazo corto, y se mira
/// **qué** contestó: la raíz de la API responde un saludo que nombra a
/// Cliniq, y un portal cautivo no puede imitarlo.
///
/// Además de preguntar, escucha: cada petición de la aplicación que vuelve
/// bien o se cae por falta de red le cuenta lo que pasó (`anotarExito`,
/// `anotarFallo`), así que casi nunca hace falta preguntar aparte.
///
/// Las pantallas lo leen por [actual], que avisa cuando cambia: es lo que
/// enciende el cartel de sin conexión y apaga los botones que necesitan red.
class SondeoDeRed {
  /// La raíz de la API: pública, pequeña y sin sesión.
  static const String _rutaDeSondeo = '';

  static const Duration _plazo = Duration(seconds: 4);

  /// Cuánto vale una respuesta antes de volver a preguntar.
  static const Duration vigencia = Duration(seconds: 15);

  /// Cada cuánto se vuelve a preguntar mientras no hay conexión, para que el
  /// cartel se vaya solo cuando vuelve la red.
  static const Duration _reintento = Duration(seconds: 20);

  /// Marca de la petición del sondeo, para que el corte rápido la deje pasar.
  static const String marcaDeSondeo = 'cliniq_sondeo_de_red';

  final Dio? _dioInyectado;

  static SondeoDeRed? _instancia;

  /// Uno solo para toda la aplicación: la respuesta se comparte entre
  /// pantallas y los quince segundos de vigencia sirven para todas.
  factory SondeoDeRed([Dio? dio]) => _instancia ??= SondeoDeRed._(dio);

  SondeoDeRed._(this._dioInyectado);

  /// Suelta la instancia única. Solo para las pruebas.
  @visibleForTesting
  static void olvidarLaInstancia() {
    _instancia?._vigilancia?.cancel();
    _instancia = null;
  }

  /*
   * El cliente se resuelve tarde, en el primer uso: `ApiClient` construye su
   * interceptor, el interceptor anota aquí, y pedir `ApiClient().dio` en el
   * constructor sería pedir el cliente en mitad de su propia construcción.
   */
  Dio get _dio => _dioInyectado ?? ApiClient().dio;

  /// Lo último que se sabe de la red, o `null` si todavía no se sabe nada.
  final ValueNotifier<EstadoDeLaRed?> actual = ValueNotifier(null);

  DateTime? _cuando;
  Future<EstadoDeLaRed>? _enCurso;
  Timer? _vigilancia;

  /// Lo último que se sabe, si todavía vale. No pregunta: solo mira.
  EstadoDeLaRed? get conocidoReciente {
    final cuando = _cuando;

    if (actual.value == null || cuando == null) return null;

    return DateTime.now().difference(cuando) < vigencia ? actual.value : null;
  }

  /// Si con lo que se sabe hay red. Sin saber nada se asume que sí: apagar
  /// botones por una sospecha estorbaría justo en el caso normal.
  bool get hayRed => actual.value?.hayInternet ?? true;

  void _recordar(EstadoDeLaRed estado) {
    _cuando = DateTime.now();
    actual.value = estado;
  }

  /// Una petición de la aplicación volvió con respuesta de la API.
  void anotarExito() => _recordar(const EstadoDeLaRed(MotivoDeRed.conectado));

  /// Una petición de la aplicación falló: se anota lo que eso dice de la red.
  void anotarFallo(DioException error) {
    if (error.requestOptions.extra[marcaDeSondeo] == true) return;

    final respuesta = error.response;

    _recordar(
      EstadoDeLaRed(
        respuesta != null
            ? clasificarRespuesta(respuesta)
            : clasificarFallo(error),
      ),
    );
  }

  /// Olvida lo sabido: quien pide reintentar cree que la red cambió.
  void olvidar() => _cuando = null;

  /// El estado, reutilizando la última respuesta si es reciente.
  Future<EstadoDeLaRed> estado({bool forzar = false}) async {
    final reciente = conocidoReciente;

    if (!forzar && reciente != null) return reciente;

    // Quien llega mientras ya hay una pregunta en el aire se engancha a ella.
    final enCurso = _enCurso;
    if (enCurso != null) return enCurso;

    final pregunta = _preguntar();
    _enCurso = pregunta;

    try {
      final estado = await pregunta;
      _recordar(estado);
      return estado;
    } finally {
      _enCurso = null;
    }
  }

  /// Vuelve a preguntar cada tanto mientras no haya conexión.
  void vigilar() {
    _vigilancia?.cancel();
    _vigilancia = Timer.periodic(_reintento, (_) {
      if (actual.value?.hayInternet ?? true) return;

      unawaited(estado(forzar: true));
    });
  }

  Future<EstadoDeLaRed> _preguntar() async {
    try {
      final respuesta = await _dio.get<dynamic>(
        _rutaDeSondeo,
        options: Options(
          extra: const {marcaDeSondeo: true},
          sendTimeout: _plazo,
          receiveTimeout: _plazo,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          headers: {'Cache-Control': 'no-cache'},
        ),
      );

      return EstadoDeLaRed(clasificarRespuesta(respuesta));
    } on DioException catch (error) {
      return EstadoDeLaRed(clasificarFallo(error));
    } catch (_) {
      return const EstadoDeLaRed(MotivoDeRed.sinRed);
    }
  }
}

/// Qué significa lo que contestó el servidor.
///
/// La API contesta JSON, salvo su raíz, que saluda nombrando a Cliniq. Un
/// portal cautivo contesta HTML con un 200 tan campante: sin mirar esto, la
/// aplicación se lo tragaría como una respuesta buena.
MotivoDeRed clasificarRespuesta(Response<dynamic> respuesta) {
  final tipo = (respuesta.headers.value('content-type') ?? '').toLowerCase();
  final codigo = respuesta.statusCode ?? 0;
  final cuerpo = respuesta.data;

  if (codigo >= 300 && codigo < 400) return MotivoDeRed.sinSalida;
  if (codigo >= 500) return MotivoDeRed.servidorCaido;

  if (tipo.contains('text/html')) {
    final esNuestra =
        cuerpo is String && cuerpo.toLowerCase().contains('cliniq');

    return esNuestra ? MotivoDeRed.conectado : MotivoDeRed.sinSalida;
  }

  // Un 2xx con JSON, o un 4xx: el servidor está contestando.
  return MotivoDeRed.conectado;
}

/// Y qué significa que ni siquiera se pudiera preguntar.
MotivoDeRed clasificarFallo(DioException error) {
  return switch (error.type) {
    DioExceptionType.connectionError => MotivoDeRed.sinRed,
    DioExceptionType.connectionTimeout => MotivoDeRed.sinSalida,
    DioExceptionType.sendTimeout => MotivoDeRed.sinSalida,
    DioExceptionType.receiveTimeout => MotivoDeRed.sinSalida,
    DioExceptionType.badCertificate => MotivoDeRed.sinSalida,
    DioExceptionType.badResponse =>
      error.response != null
          ? clasificarRespuesta(error.response!)
          : MotivoDeRed.servidorCaido,
    _ => MotivoDeRed.sinRed,
  };
}
