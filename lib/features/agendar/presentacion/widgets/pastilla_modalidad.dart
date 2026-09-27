import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../citas/data/models/cita.dart';
import '../../../citas/presentacion/estilos_cita.dart';

/// La pastilla de una modalidad, con el nombre, el color y el icono del
/// catálogo, y un [detalle] opcional («30 min»).
class PastillaModalidad extends StatelessWidget {
  final TipoCita tipo;
  final String? detalle;

  const PastillaModalidad({super.key, required this.tipo, this.detalle});

  @override
  Widget build(BuildContext context) {
    final estilo = context.modalidad(tipo);

    return Pastilla(
      texto: detalle == null ? estilo.nombre : '${estilo.nombre} · $detalle',
      color: estilo.color,
      icono: estilo.icono,
    );
  }
}
