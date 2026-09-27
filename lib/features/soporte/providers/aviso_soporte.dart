// lib/features/soporte/providers/aviso_soporte.dart

import 'package:equatable/equatable.dart';

/// Un aviso para la persona (verde o rojo). La [secuencia] distingue dos
/// avisos iguales seguidos, para que la pantalla enseñe los dos.
class AvisoSoporte extends Equatable {
  final bool exito;
  final String mensaje;
  final int secuencia;

  const AvisoSoporte({
    required this.mensaje,
    required this.secuencia,
    this.exito = false,
  });

  @override
  List<Object?> get props => [exito, mensaje, secuencia];
}
