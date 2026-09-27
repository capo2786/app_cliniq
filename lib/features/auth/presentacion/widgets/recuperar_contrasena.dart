import 'package:flutter/material.dart';

import '../../../../core/network/errores.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/auth_service.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/formato/fechas.dart';

/// Abre la hoja para pedir el enlace de recuperación de contraseña.
Future<void> mostrarRecuperarContrasena(
  BuildContext context, {
  required String correoInicial,
  required AuthService servicio,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) =>
        _RecuperarContrasena(correoInicial: correoInicial, servicio: servicio),
  );
}

/// Pedir un enlace para crear una contraseña nueva.
///
/// La API responde siempre lo mismo, exista o no el correo, para no revelar
/// quién tiene cuenta. El enlace llega al correo: abierto en el teléfono,
/// abre la aplicación en la pantalla de la contraseña nueva
/// (`RestablecerPage`, por App Links o Universal Links); en una
/// computadora, la página del panel. Vence en los minutos que diga la
/// configuración (`seguridad.resetMinutos`).
class _RecuperarContrasena extends StatefulWidget {
  final String correoInicial;
  final AuthService servicio;

  const _RecuperarContrasena({
    required this.correoInicial,
    required this.servicio,
  });

  @override
  State<_RecuperarContrasena> createState() => _RecuperarContrasenaState();
}

class _RecuperarContrasenaState extends State<_RecuperarContrasena> {
  late final TextEditingController _correo = TextEditingController(
    text: widget.correoInicial,
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _enviando = false;
  String? _respuesta;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_formKey.currentState?.validate() != true || _enviando) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final mensaje = await widget.servicio.pedirRecuperacion(_correo.text);
      if (!mounted) return;
      setState(() => _respuesta = mensaje);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final respuesta = _respuesta;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
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
            const Text(
              'Recuperar contraseña',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Te enviaremos un enlace a tu correo. Ábrelo desde el teléfono '
              'o la computadora para crear una contraseña nueva.',
              style: TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            if (respuesta != null) ...[
              RecuadroAviso(
                mensaje:
                    '$respuesta El enlace vence en '
                    '${minutos(context.config.seguridad.resetMinutos)}.',
                icono: Icons.mark_email_read_outlined,
                color: AppColors.exito,
                colorTexto: AppColors.texto,
              ),
              const SizedBox(height: 16),
              BotonSecundario(
                texto: 'Listo',
                icono: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else ...[
              if (_error != null) ...[
                RecuadroAviso.error(_error!),
                const SizedBox(height: 14),
              ],
              const EtiquetaCampo('Correo electrónico'),
              CampoCliniq(
                controller: _correo,
                pista: 'tucorreo@ejemplo.com',
                icono: Icons.alternate_email_rounded,
                teclado: TextInputType.emailAddress,
                accion: TextInputAction.send,
                habilitado: !_enviando,
                validator: (valor) {
                  final texto = valor?.trim() ?? '';
                  if (texto.isEmpty) return 'Ingresa tu correo electrónico.';
                  if (!texto.contains('@')) {
                    return 'Ese correo no parece válido.';
                  }
                  return null;
                },
                onSubmitted: (_) => _enviar(),
              ),
              const SizedBox(height: 18),
              BotonPrincipal(
                texto: 'Enviar enlace',
                icono: Icons.send_rounded,
                cargando: _enviando,
                textoCargando: 'Enviando…',
                onPressed: _enviar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
