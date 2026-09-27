// lib/features/ayuda/presentacion/articulo_ayuda_page.dart

import 'package:flutter/material.dart';

import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/tema/tokens.dart';
import '../../soporte/presentacion/soporte_page.dart';
import '../data/models/articulo_ayuda.dart';
import 'enlaces_de_ayuda.dart';
import 'widgets/acceso_a_soporte.dart';
import 'widgets/markdown_nativo.dart';

/// Un artículo del centro de ayuda, entero y nativo. Al final, para quien
/// no resolvió su duda, el acceso a escribir a soporte con el formulario del
/// ticket nuevo ya abierto.
class ArticuloAyudaPage extends StatelessWidget {
  final ArticuloAyuda articulo;

  /// Para los enlaces a rutas de otros módulos (ver `abrirEnlaceDeAyuda`).
  final AbrirRutaInterna? abrirRuta;

  const ArticuloAyudaPage({super.key, required this.articulo, this.abrirRuta});

  void _escribirASoporte(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SoportePage(nuevoTicket: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Centro de ayuda')),
      body: FondoDegradado(
        child: ListView(
          padding: context.margenDeScroll(inferior: 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Pastilla(
                texto: articulo.grupo,
                color: AppColors.primarioClaro,
                icono: Icons.folder_open_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              articulo.titulo,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            TarjetaTranslucida(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: MarkdownNativo(
                markdown: articulo.contenido,
                alTocarEnlace: (url) =>
                    abrirEnlaceDeAyuda(context, url, abrirRuta: abrirRuta),
              ),
            ),
            const SizedBox(height: 22),
            AccesoASoporte(
              key: const Key('acceso-soporte-articulo'),
              titulo: '¿No resolviste tu duda?',
              descripcion:
                  'Escribe a soporte: te responde una persona del equipo.',
              accion: 'Escribir a soporte',
              alTocar: () => _escribirASoporte(context),
            ),
          ],
        ),
      ),
    );
  }
}
