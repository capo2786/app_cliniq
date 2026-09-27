// lib/core/presentacion/estilo_de_catalogo.dart

import 'package:flutter/material.dart';

import '../catalogos/catalogos_cubit.dart';
import '../tema/tokens.dart';
import 'visual_del_servidor.dart';

/// Cómo se ve un código del sistema —una modalidad, un estado— según su
/// catálogo: nombre, descripción, color e icono, todo lo que edita el
/// administrador.
///
/// El color es información, no adorno: de un vistazo se distingue una
/// videollamada de una consulta en persona, o una cita cancelada de una
/// programada. Por eso cada uno lleva además su icono —el color solo no
/// basta para quien no distingue colores—.
class EstiloDeCatalogo {
  final String nombre;
  final String descripcion;
  final Color color;
  final IconData icono;

  const EstiloDeCatalogo({
    required this.nombre,
    required this.descripcion,
    required this.color,
    required this.icono,
  });

  /// El del código en el catálogo. Si el catálogo no lo trae (lo
  /// desactivaron, o esta versión conoce un código que la clínica todavía no
  /// sembró), se enseña el código tal cual, con el icono genérico y el color
  /// del tema: nada inventado.
  factory EstiloDeCatalogo.de(
    CatalogosState catalogos,
    String clave,
    String codigo,
  ) {
    final item = catalogos.porCodigo(clave, codigo);

    return EstiloDeCatalogo(
      nombre: item?.nombre ?? codigo,
      descripcion: item?.descripcion ?? '',
      color: colorDelServidor(item?.color) ?? AppColors.primarioClaro,
      icono: iconoDelServidor(item?.icono),
    );
  }

  /// «Telemedicina · Videollamada en vivo», o solo el nombre.
  String get conDescripcion =>
      descripcion.isEmpty ? nombre : '$nombre · $descripcion';
}
