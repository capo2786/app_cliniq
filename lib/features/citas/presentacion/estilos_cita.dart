import 'package:flutter/widgets.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/estilo_de_catalogo.dart';
import '../data/models/cita.dart';

/*
 * Cómo se ven las modalidades (catálogo `MODALIDAD_CITA`) y los estados
 * (`ESTADO_CITA`): nombre, descripción, color e icono salen del catálogo, ver
 * `EstiloDeCatalogo`. Aquí no queda ningún mapa de colores ni de nombres.
 */

/// Las modalidades que la clínica tiene activas en `MODALIDAD_CITA`, en el
/// orden del panel. Las que el catálogo no trae no se ofrecen como filtro.
List<TipoCita> modalidadesDelCatalogo(CatalogosState catalogos) => [
  for (final item in catalogos.items(Catalogos.modalidadCita))
    for (final tipo in TipoCita.values)
      if (tipo.codigo == item.codigo.toUpperCase()) tipo,
];

/// El estilo de una modalidad según el catálogo.
EstiloDeCatalogo estiloDeModalidad(CatalogosState catalogos, TipoCita tipo) =>
    EstiloDeCatalogo.de(catalogos, Catalogos.modalidadCita, tipo.codigo);

/// El estilo de un estado de cita según el catálogo.
EstiloDeCatalogo estiloDeEstadoCita(
  CatalogosState catalogos,
  EstadoCita estado,
) => EstiloDeCatalogo.de(catalogos, Catalogos.estadoCita, estado.codigo);

/// Los estilos desde una pantalla (escuchan los catálogos).
extension EstilosDeCitaEnContexto on BuildContext {
  EstiloDeCatalogo modalidad(TipoCita tipo) =>
      estiloDeModalidad(catalogos, tipo);

  EstiloDeCatalogo estadoCita(EstadoCita estado) =>
      estiloDeEstadoCita(catalogos, estado);
}
