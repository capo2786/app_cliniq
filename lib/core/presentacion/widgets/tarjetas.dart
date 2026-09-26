import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// La tarjeta que abre cada pantalla de contenido.
///
/// Va sobre `AppGradientes.encabezado`: el mismo gris azulado en citas, en
/// dependientes y en el perfil, para que cada pantalla se reconozca como
/// parte de la misma aplicación.
class TarjetaEncabezado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  /// Algo a la derecha: un contador, un botón.
  final Widget? accesorio;

  const TarjetaEncabezado({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accesorio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: AppGradientes.encabezado,
        borderRadius: AppRadio.dePanel,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.sombraSuave,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icono, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (accesorio != null) ...[const SizedBox(width: 10), accesorio!],
        ],
      ),
    );
  }
}

/// Etiqueta de sección en mayúsculas, sobre cada grupo de tarjetas.
class EtiquetaSeccion extends StatelessWidget {
  final String texto;

  const EtiquetaSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 2, bottom: AppEspaciado.m),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta semitransparente sobre el fondo degradado.
///
/// No es un bloque opaco a propósito: deja pasar algo del gris azulado de
/// atrás y la pantalla se lee como una sola pieza.
class TarjetaTranslucida extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Un color para teñir el borde y el fondo (una modalidad, un estado).
  final Color? tinte;

  const TarjetaTranslucida({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppEspaciado.l),
    this.onTap,
    this.tinte,
  });

  @override
  Widget build(BuildContext context) {
    final borde = tinte?.withValues(alpha: 0.32) ?? AppColors.bordeCampo;

    final contenido = Ink(
      padding: padding,
      decoration: BoxDecoration(
        gradient: tinte == null
            ? null
            : LinearGradient(
                colors: [
                  tinte!.withValues(alpha: 0.12),
                  AppColors.tarjetaPlana,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: tinte == null ? AppColors.tarjetaPlana : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borde),
      ),
      child: child,
    );

    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? contenido
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              splashColor: (tinte ?? AppColors.primarioClaro).withValues(
                alpha: 0.14,
              ),
              child: contenido,
            ),
    );
  }
}

/// Un dato con su rótulo, dentro de una tarjeta: «Teléfono · 099…».
class FilaDato extends StatelessWidget {
  final IconData icono;
  final String rotulo;
  final String? valor;

  /// Qué decir cuando el dato falta.
  final String vacio;

  const FilaDato({
    super.key,
    required this.icono,
    required this.rotulo,
    required this.valor,
    this.vacio = 'Sin registrar',
  });

  @override
  Widget build(BuildContext context) {
    final texto = valor?.trim() ?? '';
    final falta = texto.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.primarioClaro, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  falta ? vacio : texto,
                  style: TextStyle(
                    color: falta ? AppColors.textoTenue : AppColors.texto,
                    fontSize: 14,
                    fontWeight: falta ? FontWeight.w500 : FontWeight.w600,
                    fontStyle: falta ? FontStyle.italic : FontStyle.normal,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una pastilla pequeña con icono y texto: modalidad, estado, «Para Ana».
class Pastilla extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;

  const Pastilla({
    super.key,
    required this.texto,
    required this.color,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, color: color, size: 13),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
