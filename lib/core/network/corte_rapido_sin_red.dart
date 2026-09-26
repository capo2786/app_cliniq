import 'package:dio/dio.dart';

import '../red/estado_de_la_red.dart';

/// Que nadie espere diez segundos por una red que ya se sabe que no lleva a
/// ninguna parte.
///
/// Cuando una petición se cae por falta de red, se anota en el sondeo. Durante
/// los quince segundos siguientes cualquier otra petición se corta de
/// inmediato con el mismo error que habría dado al agotar el plazo, y los
/// módulos lo recogen en su `catch` de siempre: el que los lleva a lo
/// guardado en el teléfono. La primera petición paga el plazo; las demás, no.
///
/// No corta el sondeo —es la pregunta con la que se averigua si volvió la
/// red— ni el servidor caído: ahí sí se llega, y su error tiene que verse.
class CorteRapidoSinRed extends Interceptor {
  SondeoDeRed? _sondeoResuelto;

  final SondeoDeRed? _sondeoInyectado;

  CorteRapidoSinRed([SondeoDeRed? sondeo]) : _sondeoInyectado = sondeo;

  SondeoDeRed get _sondeo =>
      _sondeoInyectado ?? (_sondeoResuelto ??= SondeoDeRed());

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[SondeoDeRed.marcaDeSondeo] == true ||
        !hayQueCortar(_sondeo.conocidoReciente)) {
      return handler.next(options);
    }

    handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'Sin salida a Internet comprobada hace un momento.',
      ),
      true,
    );
  }
}

/// Si con lo que se sabe de la red hay que cortar sin intentarlo.
bool hayQueCortar(EstadoDeLaRed? conocido) {
  if (conocido == null) return false;

  return switch (conocido.motivo) {
    MotivoDeRed.sinRed => true,
    MotivoDeRed.sinSalida => true,
    MotivoDeRed.servidorCaido => false,
    MotivoDeRed.conectado => false,
  };
}
