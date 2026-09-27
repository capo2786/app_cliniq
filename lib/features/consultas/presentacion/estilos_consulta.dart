import 'package:flutter/material.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/estilo_de_catalogo.dart';
import '../../../core/tema/tokens.dart';
import '../data/models/consulta.dart';

/// El estilo de un estado de consulta según el catálogo `ESTADO_CONSULTA`:
/// etiqueta, color, icono y, en la descripción, lo que significa para el
/// paciente. Como en las citas, el color va siempre con su icono.
EstiloDeCatalogo estiloDeEstadoConsulta(
  CatalogosState catalogos,
  EstadoConsulta estado,
) => EstiloDeCatalogo.de(catalogos, Catalogos.estadoConsulta, estado.codigo);

/// El estilo de un estado desde una pantalla (escucha los catálogos).
extension EstiloEstadoConsultaEnContexto on BuildContext {
  EstiloDeCatalogo estadoConsulta(EstadoConsulta estado) =>
      estiloDeEstadoConsulta(catalogos, estado);
}

/// El color del plazo: ámbar si queda poco, rojo si ya se pasó.
Color colorDelPlazo(String? plazo) {
  if (plazo == null) return AppColors.acentoClaro;
  if (plazo == 'Demorada') return AppColors.peligroSuave;
  if (plazo.contains('min') || plazo == 'Queda 1 h') return AppColors.alerta;

  return AppColors.acentoClaro;
}
