import 'package:flutter/widgets.dart';

/// Avisa a una pantalla cuando otra se le pone encima y cuando vuelve a
/// quedar a la vista.
///
/// Lo usa el detalle de una consulta en línea para preguntar por mensajes
/// nuevos solo mientras se ve: con el visor de una imagen abierto encima, o
/// con la aplicación en segundo plano, no tiene sentido gastar datos.
/// Va registrado en `MaterialApp.navigatorObservers`.
final RouteObserver<ModalRoute<void>> observadorDeRutas =
    RouteObserver<ModalRoute<void>>();
