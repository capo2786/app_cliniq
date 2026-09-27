// lib/features/soporte/presentacion/estilos_soporte.dart

import 'package:flutter/widgets.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/estilo_de_catalogo.dart';
import '../data/models/ticket.dart';

/*
 * Cómo se ven los estados (`ESTADO_TICKET`), las severidades
 * (`SEVERIDAD_TICKET`) y las categorías (`CATEGORIA_TICKET`) de un ticket:
 * nombre, descripción, color e icono salen del catálogo. Un código que el
 * catálogo no trae se enseña tal cual (ver `EstiloDeCatalogo`).
 */
extension EstilosDeSoporteEnContexto on BuildContext {
  EstiloDeCatalogo estadoTicket(EstadoTicket estado) =>
      EstiloDeCatalogo.de(catalogos, Catalogos.estadoTicket, estado.codigo);

  EstiloDeCatalogo severidadTicket(String codigo) =>
      EstiloDeCatalogo.de(catalogos, Catalogos.severidadTicket, codigo);

  EstiloDeCatalogo categoriaTicket(String codigo) =>
      EstiloDeCatalogo.de(catalogos, Catalogos.categoriaTicket, codigo);
}
