// lib/features/navegacion/presentacion/muy_pronto_page.dart

import 'package:flutter/material.dart';

import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/tema/tokens.dart';

/// Una pantalla que la aplicación ya conoce pero todavía no trae.
///
/// El enrutador sabe a dónde lleva la ruta (el menú de la clínica o un aviso
/// la mandan) y la abre aquí, dentro de la aplicación, en vez de mandar a la
/// persona al panel web en el navegador. [titulo] es el nombre con que la
/// llamó el administrador en el menú, si llegó desde ahí.
class MuyProntoPage extends StatelessWidget {
  final String titulo;

  const MuyProntoPage({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('muy-pronto'),
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: Text(titulo)),
      body: FondoDegradado(
        child: ListView(
          padding: context.margenDeScroll(superior: 28),
          children: [
            EstadoVacio(
              icono: Icons.auto_awesome_outlined,
              titulo: 'Muy pronto',
              descripcion:
                  '«$titulo» estará disponible en la aplicación muy pronto. '
                  'Mientras tanto, puedes seguir usando el resto de la '
                  'aplicación con normalidad.',
            ),
          ],
        ),
      ),
    );
  }
}
