// lib/features/mediciones/escaner/fuente_de_cuadros.dart

import 'package:flutter/widgets.dart';

import 'serie_senal.dart';

/// Por qué no se pudo abrir la cámara.
enum MotivoErrorCamara {
  /// La persona no dio el permiso; se puede volver a pedir.
  permisoNegado,

  /// El permiso ya no se puede pedir desde la aplicación: solo en los
  /// ajustes del teléfono.
  permisoBloqueado,

  /// El teléfono no tiene esa cámara (la trasera o la frontal).
  sinCamara,

  /// La cámara trasera no deja encender el flash (modo dedo).
  sinLinterna,

  /// Otro fallo del sistema al abrirla.
  otro,
}

class ErrorDeCamara implements Exception {
  final MotivoErrorCamara motivo;

  const ErrorDeCamara(this.motivo);

  /// Lo que se le dice a la persona.
  String get mensaje => switch (motivo) {
    MotivoErrorCamara.permisoNegado =>
      'Para medir hace falta la cámara. Toca «Reintentar» y permite el acceso.',
    MotivoErrorCamara.permisoBloqueado =>
      'El permiso de la cámara está apagado para esta aplicación. Puedes '
          'encenderlo en los ajustes del teléfono.',
    MotivoErrorCamara.sinCamara =>
      'Este teléfono no tiene la cámara que hace falta para este modo.',
    MotivoErrorCamara.sinLinterna =>
      'Este teléfono no deja encender el flash mientras usa la cámara. '
          'Prueba con el modo rostro.',
    MotivoErrorCamara.otro =>
      'No pudimos abrir la cámara. Cierra otras aplicaciones que la estén '
          'usando y vuelve a intentarlo.',
  };

  @override
  String toString() => 'ErrorDeCamara($motivo)';
}

/// De dónde salen los cuadros del escáner.
///
/// La de verdad es [FuenteCamara] (el paquete `camera`, con el flash en el
/// modo dedo); las pruebas de las pantallas usan una falsa que entrega una
/// señal sintética. Lo que sale de aquí ya son números ([CuadroPpg]): la
/// imagen no pasa de la fuente.
abstract class FuenteDeCuadros {
  /// Pide el permiso, abre la cámara del modo (la trasera con el flash
  /// encendido, o la frontal) y empieza a entregar cuadros. Lanza
  /// [ErrorDeCamara] si no puede.
  Future<void> abrir(ModoEscaner modo);

  /// Los cuadros, con su momento desde [abrir].
  Stream<CuadroPpg> get cuadros;

  /// Lo que se ve en pantalla mientras se mide: la vista de la cámara
  /// frontal en el modo rostro (para encajar la cara en el óvalo), o nada.
  Widget vistaPrevia(BuildContext context);

  /// Apaga el flash y suelta la cámara. Se puede llamar más de una vez.
  Future<void> cerrar();

  /// Abre los ajustes de la aplicación en el teléfono (para el permiso).
  Future<bool> abrirAjustes();
}
