import 'package:equatable/equatable.dart';

import '../../../core/archivos/selector_de_archivos.dart';

sealed class DetalleConsultaEvent extends Equatable {
  const DetalleConsultaEvent();

  @override
  List<Object?> get props => [];
}

/// Abrir la consulta: lo guardado primero, si hay, y después el servidor.
class DetalleConsultaSolicitado extends DetalleConsultaEvent {
  const DetalleConsultaSolicitado();
}

/// Preguntar por novedades. [silencioso] es el sondeo periódico (y el
/// regreso a la pantalla): pregunta por la lista de resúmenes, solo trae el
/// detalle si esta consulta cambió y, si falla, no dice nada. Al deslizar
/// para refrescar se vuelve a pedir el detalle y un fallo sí se avisa.
class DetalleConsultaRefrescado extends DetalleConsultaEvent {
  final bool silencioso;

  const DetalleConsultaRefrescado({this.silencioso = false});

  @override
  List<Object?> get props => [silencioso];
}

/// Encender o apagar el sondeo cada 30 segundos (la pantalla lo apaga al
/// quedar tapada o al irse la aplicación a segundo plano).
class DetalleConsultaSondeoCambiado extends DetalleConsultaEvent {
  final bool activo;

  const DetalleConsultaSondeoCambiado(this.activo);

  @override
  List<Object?> get props => [activo];
}

/// Un archivo para acompañar el próximo mensaje.
class DetalleConsultaAdjuntoElegido extends DetalleConsultaEvent {
  final SeleccionDeArchivos seleccion;

  const DetalleConsultaAdjuntoElegido(this.seleccion);

  @override
  List<Object?> get props => [seleccion.archivos, seleccion.problemas];
}

class DetalleConsultaAdjuntoQuitado extends DetalleConsultaEvent {
  const DetalleConsultaAdjuntoQuitado();
}

class DetalleConsultaMensajeEnviado extends DetalleConsultaEvent {
  final String texto;

  const DetalleConsultaMensajeEnviado(this.texto);

  @override
  List<Object?> get props => [texto];
}

/// Cancelar una consulta ENVIADA, con su motivo.
class DetalleConsultaCancelada extends DetalleConsultaEvent {
  final String motivo;

  const DetalleConsultaCancelada(this.motivo);

  @override
  List<Object?> get props => [motivo];
}
