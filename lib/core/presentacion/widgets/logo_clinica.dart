// lib/core/presentacion/widgets/logo_clinica.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../configuracion/config_publica_cubit.dart';
import '../../tema/tokens.dart';
import 'logo_cliniq.dart';

/// Una imagen que llegó como data URL (`data:image/png;base64,…`).
class ImagenDataUrl {
  final String mime;
  final Uint8List bytes;

  const ImagenDataUrl(this.mime, this.bytes);

  bool get esSvg => mime.contains('svg');

  static String? _ultimaFuente;
  static ImagenDataUrl? _ultima;

  /// Decodifica un data URL de imagen (PNG, JPG o SVG), o `null` si no lo
  /// es. Se recuerda el último: el logotipo se pinta en muchas pantallas y no
  /// hace falta decodificarlo en cada una.
  static ImagenDataUrl? desde(String? fuente) {
    if (fuente == null || fuente.isEmpty) return null;
    if (fuente == _ultimaFuente) return _ultima;

    ImagenDataUrl? imagen;
    try {
      final datos = UriData.parse(fuente);
      final mime = datos.mimeType.toLowerCase();
      final bytes = datos.contentAsBytes();

      if (mime.startsWith('image/') && bytes.isNotEmpty) {
        imagen = ImagenDataUrl(mime, bytes);
      }
    } catch (_) {
      imagen = null;
    }

    _ultimaFuente = fuente;
    _ultima = imagen;
    return imagen;
  }
}

/// El logotipo de la clínica: el que el administrador subió
/// (`clinica.logo`) o, si no subió ninguno, el de la marca que la
/// aplicación ya trae dibujado.
///
/// Con [insignia] va sobre la pastilla clara del acceso y del arranque.
/// Antes de tener la configuración —el primer arranque— se ve el de marca.
class LogoDeLaClinica extends StatelessWidget {
  final double tamano;
  final bool insignia;

  const LogoDeLaClinica({super.key, this.tamano = 64, this.insignia = false});

  @override
  Widget build(BuildContext context) {
    ({String? logo, String nombre})? datos;
    try {
      datos = context
          .select<ConfigPublicaCubit, ({String? logo, String nombre})>(
            (cubit) => (
              logo: cubit.state.config?.clinica.logo,
              nombre: cubit.state.config?.clinica.nombre ?? '',
            ),
          );
    } catch (_) {
      datos = null;
    }

    final imagen = ImagenDataUrl.desde(datos?.logo);
    final deMarca = insignia
        ? InsigniaCliniq(tamano: tamano)
        : LogoCliniq(tamano: tamano);

    if (imagen == null) return deMarca;

    final lado = insignia ? tamano * 0.68 : tamano;
    final dibujo = imagen.esSvg
        ? SvgPicture.memory(
            imagen.bytes,
            width: lado,
            height: lado,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => SizedBox.square(dimension: lado),
          )
        : Image.memory(
            imagen.bytes,
            width: lado,
            height: lado,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // Una imagen que no se puede leer no deja un hueco: se ve la
            // de marca.
            errorBuilder: (_, _, _) => deMarca,
          );

    final conNombre = Semantics(
      label: datos?.nombre,
      image: true,
      child: ExcludeSemantics(child: dibujo),
    );

    if (!insignia) return SizedBox.square(dimension: tamano, child: conNombre);

    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * 0.16),
      decoration: BoxDecoration(
        color: AppColors.fondoIcono.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(tamano * 0.29),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.acento.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(child: conNombre),
    );
  }
}
