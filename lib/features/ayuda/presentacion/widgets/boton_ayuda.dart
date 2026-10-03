// lib/features/ayuda/presentacion/widgets/boton_ayuda.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/tema/tokens.dart';
import '../../../navegacion/presentacion/enrutador.dart';
import '../../data/models/ayuda_de_accion.dart';
import '../../providers/ayuda_contextual_cubit.dart';
import '../centro_ayuda_page.dart';
import '../enlaces_de_ayuda.dart';
import 'markdown_nativo.dart';

/// El botón de ayuda («?») de una pantalla o de una acción: abre una hoja
/// con qué hace, cuándo usarla y qué pasa después, y, si la hay, «Ver la
/// guía completa» en el centro de ayuda.
///
///     BotonAyuda(clave: 'app.miSalud.receta')
///
/// El texto lo escribe la clínica en el panel (artículos de ayuda con
/// clave) y llega de `GET /ayuda/contextual` (ver `AyudaContextualCubit`).
/// **Sin texto para la clave, el botón no se enseña**: ni un hueco ni un
/// texto de respaldo. Va en la barra de la pantalla ([enLinea] falso) o
/// junto a una acción ([enLinea], más pequeño).
class BotonAyuda extends StatelessWidget {
  final String clave;

  /// Junto a una acción o un título, en vez de en la barra.
  final bool enLinea;

  const BotonAyuda({super.key, required this.clave, this.enLinea = false});

  @override
  Widget build(BuildContext context) {
    final AyudaContextualCubit cubit;
    try {
      cubit = context.read<AyudaContextualCubit>();
    } on ProviderNotFoundException {
      // Fuera de la aplicación con sesión (una pantalla suelta): sin textos.
      return const SizedBox.shrink();
    }

    return BlocSelector<
      AyudaContextualCubit,
      AyudaContextualState,
      AyudaDeAccion?
    >(
      bloc: cubit,
      selector: (state) => state.de(clave),
      builder: (context, ayuda) {
        if (ayuda == null) return const SizedBox.shrink();

        return IconButton(
          key: Key('ayuda-$clave'),
          tooltip: 'Ayuda: ${ayuda.titulo}',
          onPressed: () => mostrarAyudaDeAccion(context, ayuda),
          visualDensity: enLinea ? VisualDensity.compact : null,
          color: enLinea ? AppColors.primarioClaro : null,
          icon: Icon(Icons.help_outline_rounded, size: enLinea ? 20 : null),
        );
      },
    );
  }
}

/// Abre la hoja con el texto de ayuda de una acción.
Future<void> mostrarAyudaDeAccion(BuildContext context, AyudaDeAccion ayuda) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => HojaDeAyuda(ayuda: ayuda, contextoPadre: context),
  );
}

/// La hoja de un botón de ayuda: el título, el texto en Markdown nativo
/// (sus enlaces no sacan de la aplicación) y «Ver la guía completa», que
/// abre el artículo en el centro de ayuda.
class HojaDeAyuda extends StatelessWidget {
  final AyudaDeAccion ayuda;

  /// El contexto de quien abrió la hoja: al seguir un enlace se cierra la
  /// hoja y se navega desde ahí.
  final BuildContext contextoPadre;

  const HojaDeAyuda({
    super.key,
    required this.ayuda,
    required this.contextoPadre,
  });

  void _seguirEnlace(BuildContext context, String url) {
    Navigator.of(context).pop();
    abrirEnlaceDeAyuda(contextoPadre, url, abrirRuta: _abrirRutaInterna);
  }

  void _verGuia(BuildContext context, String articuloId) {
    final navegador = Navigator.of(contextoPadre);
    Navigator.of(context).pop();

    navegador.push(
      MaterialPageRoute<void>(
        builder: (_) => CentroAyudaPage(
          articuloInicial: articuloId,
          abrirRuta: _abrirRutaInterna,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articulo = ayuda.articuloId;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bordeCampo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.acentoClaro,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ayuda.titulo,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MarkdownNativo(
              markdown: ayuda.texto,
              alTocarEnlace: (url) => _seguirEnlace(context, url),
            ),
            if (articulo != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('ver-guia-completa'),
                  onPressed: () => _verGuia(context, articulo),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.acentoClaro,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 19),
                  label: const Text(
                    'Ver la guía completa',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Las rutas de otros módulos que aparezcan en un texto de ayuda se abren
/// con el enrutador de la aplicación.
bool _abrirRutaInterna(BuildContext context, String ruta) =>
    abrirRuta(context, ruta);
