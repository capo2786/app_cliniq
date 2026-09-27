import 'package:equatable/equatable.dart';

import '../../../core/archivos/selector_de_archivos.dart';
import 'nueva_consulta_state.dart';

sealed class NuevaConsultaEvent extends Equatable {
  const NuevaConsultaEvent();

  @override
  List<Object?> get props => [];
}

/// Abrir el formulario. Con [borradorId] se retoma ese borrador; con [para]
/// se preelige a un dependiente.
class NuevaConsultaIniciada extends NuevaConsultaEvent {
  final String? borradorId;
  final String? para;

  const NuevaConsultaIniciada({this.borradorId, this.para});

  @override
  List<Object?> get props => [borradorId, para];
}

class NuevaConsultaParaElegido extends NuevaConsultaEvent {
  final String para;

  const NuevaConsultaParaElegido(this.para);

  @override
  List<Object?> get props => [para];
}

class NuevaConsultaEspecialidadElegida extends NuevaConsultaEvent {
  final String especialidad;

  const NuevaConsultaEspecialidadElegida(this.especialidad);

  @override
  List<Object?> get props => [especialidad];
}

class NuevaConsultaMotivoElegido extends NuevaConsultaEvent {
  final String motivoId;

  const NuevaConsultaMotivoElegido(this.motivoId);

  @override
  List<Object?> get props => [motivoId];
}

class NuevaConsultaMedicoElegido extends NuevaConsultaEvent {
  final String uid;

  const NuevaConsultaMedicoElegido(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// Lo respondido a una pregunta del formulario.
class NuevaConsultaRespuestaCambiada extends NuevaConsultaEvent {
  final String clave;
  final Object? valor;

  const NuevaConsultaRespuestaCambiada(this.clave, this.valor);

  @override
  List<Object?> get props => [clave, valor];
}

class NuevaConsultaDescripcionCambiada extends NuevaConsultaEvent {
  final String descripcion;

  const NuevaConsultaDescripcionCambiada(this.descripcion);

  @override
  List<Object?> get props => [descripcion];
}

/// Archivos elegidos con la cámara, la galería o el selector de archivos.
/// Se validan antes de sumarlos.
class NuevaConsultaArchivosElegidos extends NuevaConsultaEvent {
  final SeleccionDeArchivos seleccion;

  const NuevaConsultaArchivosElegidos(this.seleccion);

  @override
  List<Object?> get props => [seleccion.archivos, seleccion.problemas];
}

class NuevaConsultaAdjuntoQuitado extends NuevaConsultaEvent {
  final AdjuntoConsulta adjunto;

  const NuevaConsultaAdjuntoQuitado(this.adjunto);

  @override
  List<Object?> get props => [adjunto];
}

/// «Continuar»: el paso siguiente, si el actual está completo.
class NuevaConsultaContinuada extends NuevaConsultaEvent {
  const NuevaConsultaContinuada();
}

/// «Atrás»: el paso anterior.
class NuevaConsultaRetrocedida extends NuevaConsultaEvent {
  const NuevaConsultaRetrocedida();
}

/// Ir a un paso anterior (desde el resumen, «Cambiar»).
class NuevaConsultaPasoCambiado extends NuevaConsultaEvent {
  final PasoConsulta paso;

  const NuevaConsultaPasoCambiado(this.paso);

  @override
  List<Object?> get props => [paso];
}

/// Guardar como borrador, sin enviar.
class NuevaConsultaBorradorGuardado extends NuevaConsultaEvent {
  const NuevaConsultaBorradorGuardado();
}

/// Enviar al médico.
class NuevaConsultaConfirmada extends NuevaConsultaEvent {
  const NuevaConsultaConfirmada();
}

/// Descartar: borra el borrador del servidor, si lo había.
class NuevaConsultaDescartada extends NuevaConsultaEvent {
  const NuevaConsultaDescartada();
}

/// Se agregó un dependiente desde el paso «para quién».
class NuevaConsultaDependientesRecargados extends NuevaConsultaEvent {
  final String? elegir;

  const NuevaConsultaDependientesRecargados({this.elegir});

  @override
  List<Object?> get props => [elegir];
}
