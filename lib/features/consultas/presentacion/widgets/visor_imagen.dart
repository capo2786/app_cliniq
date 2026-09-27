import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/archivos/archivo_meta.dart';
import '../../../../core/network/errores.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';

/// Una imagen de la consulta a pantalla completa, con zoom.
///
/// Se baja con la sesión (`GET /archivos/:id`) y se enseña desde memoria: no
/// queda copiada en la galería ni en ninguna carpeta del teléfono.
class VisorDeImagen extends StatefulWidget {
  final ArchivoMeta archivo;

  /// De dónde salen los bytes. Por defecto, `Servicios.archivos`.
  final Future<Uint8List> Function(String id)? descargar;

  const VisorDeImagen({super.key, required this.archivo, this.descargar});

  @override
  State<VisorDeImagen> createState() => _VisorDeImagenState();
}

class _VisorDeImagenState extends State<VisorDeImagen> {
  late Future<Uint8List> _bytes = _pedir();

  Future<Uint8List> _pedir() =>
      (widget.descargar ?? Servicios.archivos.descargar)(widget.archivo.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoProfundo,
      appBar: AppBar(
        backgroundColor: AppColors.fondoProfundo,
        title: Text(
          widget.archivo.nombre,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, instantanea) {
          if (instantanea.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.acentoClaro),
            );
          }

          final bytes = instantanea.data;

          if (instantanea.hasError || bytes == null || bytes.isEmpty) {
            return _Fallo(
              mensaje: mensajeDeError(
                instantanea.error ?? 'vacío',
                generico: 'No pudimos abrir la imagen.',
              ),
              alReintentar: () => setState(() {
                _bytes = _pedir();
              }),
            );
          }

          return InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, pila) => const _Fallo(
                  mensaje: 'La imagen está dañada y no se puede enseñar.',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Fallo extends StatelessWidget {
  final String mensaje;
  final VoidCallback? alReintentar;

  const _Fallo({required this.mensaje, this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textoSecundario,
              size: 46,
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (alReintentar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.acentoClaro,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
