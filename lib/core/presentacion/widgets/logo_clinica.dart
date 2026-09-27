// lib/core/presentacion/widgets/logo_clinica.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../configuracion/config_publica.dart';
import '../../configuracion/config_publica_cubit.dart';
import '../../configuracion/logo_clinica_service.dart';
import '../../servicios.dart';
import '../../tema/tokens.dart';
import 'logo_cliniq.dart';

/// Una imagen que llegó como data URL (`data:image/png;base64,…`): así
/// manda el logotipo un servidor anterior.
class ImagenDataUrl {
  const ImagenDataUrl._();

  static String? _ultimaFuente;
  static ImagenDeLogo? _ultima;

  /// Decodifica un data URL de imagen (PNG, JPG o SVG), o `null` si no lo
  /// es. Se recuerda el último: el logotipo se pinta en muchas pantallas y no
  /// hace falta decodificarlo en cada una.
  static ImagenDeLogo? desde(String? fuente) {
    if (fuente == null || fuente.isEmpty) return null;
    if (fuente == _ultimaFuente) return _ultima;

    ImagenDeLogo? imagen;
    try {
      final datos = UriData.parse(fuente);
      final mime = datos.mimeType.toLowerCase();
      final bytes = datos.contentAsBytes();

      if (mime.startsWith('image/') && bytes.isNotEmpty) {
        imagen = ImagenDeLogo(mime, bytes);
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
/// `clinica.logo` es la dirección del archivo (en MinIO, detrás de
/// `GET /configuracion/logo`): se baja una vez y queda guardado en el
/// teléfono ([LogoClinicaService]). De un servidor anterior llega como data
/// URL y se pinta igual.
///
/// Con [insignia] va sobre la pastilla clara del acceso y del arranque.
/// Antes de tener la configuración —el primer arranque— se ve el de marca;
/// mientras se baja por primera vez, el hueco del mismo tamaño; si no se
/// puede bajar ni hay copia, el de marca.
class LogoDeLaClinica extends StatelessWidget {
  final double tamano;
  final bool insignia;

  /// Por defecto, `Servicios.logoClinica`.
  final LogoClinicaService? servicio;

  const LogoDeLaClinica({
    super.key,
    this.tamano = 64,
    this.insignia = false,
    this.servicio,
  });

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

    final deMarca = insignia
        ? InsigniaCliniq(tamano: tamano)
        : LogoCliniq(tamano: tamano);
    final nombre = datos?.nombre ?? '';

    return switch (OrigenDelLogo.desde(datos?.logo)) {
      null => deMarca,
      LogoEnDataUrl(:final dataUrl) => switch (ImagenDataUrl.desde(dataUrl)) {
        null => deMarca,
        final imagen => _conImagen(imagen, deMarca, nombre),
      },
      LogoEnLaRed(:final url) => _LogoDeLaRed(
        key: ValueKey(url),
        url: url,
        servicio: servicio ?? Servicios.logoClinica,
        pintar: (imagen, termino) => imagen == null && termino
            ? deMarca
            : _conImagen(imagen, deMarca, nombre),
      ),
    };
  }

  /// La imagen en su marco; sin imagen (todavía bajando), el marco vacío.
  Widget _conImagen(ImagenDeLogo? imagen, Widget deMarca, String nombre) {
    final lado = insignia ? tamano * 0.68 : tamano;

    final Widget dibujo;
    if (imagen == null) {
      dibujo = SizedBox.square(key: const Key('logo-bajando'), dimension: lado);
    } else if (imagen.esSvg) {
      dibujo = SvgPicture.memory(
        imagen.bytes,
        width: lado,
        height: lado,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox.square(dimension: lado),
      );
    } else {
      dibujo = Image.memory(
        imagen.bytes,
        width: lado,
        height: lado,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        // Una imagen que no se puede leer no deja un hueco: se ve la
        // de marca.
        errorBuilder: (_, _, _) => deMarca,
      );
    }

    final conNombre = Semantics(
      label: nombre,
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

/// Pide el logotipo de [url] al servicio y lo pinta en cuanto llega. Si ya
/// está en memoria, desde el primer cuadro.
class _LogoDeLaRed extends StatefulWidget {
  final Uri url;
  final LogoClinicaService servicio;
  final Widget Function(ImagenDeLogo? imagen, bool termino) pintar;

  const _LogoDeLaRed({
    super.key,
    required this.url,
    required this.servicio,
    required this.pintar,
  });

  @override
  State<_LogoDeLaRed> createState() => _LogoDeLaRedState();
}

class _LogoDeLaRedState extends State<_LogoDeLaRed> {
  ImagenDeLogo? _imagen;
  bool _termino = false;

  @override
  void initState() {
    super.initState();

    _imagen = widget.servicio.enMemoria(widget.url);
    if (_imagen != null) {
      _termino = true;
      return;
    }

    widget.servicio.obtener(widget.url).then((imagen) {
      if (!mounted) return;
      setState(() {
        _imagen = imagen;
        _termino = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.pintar(_imagen, _termino);
}
