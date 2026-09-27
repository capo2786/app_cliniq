// lib/core/presentacion/widgets/redactor_de_mensaje.dart

import 'package:flutter/material.dart';

import '../../tema/tokens.dart';
import '../margenes.dart';
import 'aviso_sin_conexion.dart';

/// El redactor de una conversación: el texto, un archivo opcional y
/// enviar. Lo usan las consultas en línea y los tickets de soporte.
///
/// Va dentro del cuerpo de la pantalla, al pie de una `Column`, y no como
/// barra inferior: así el `Scaffold` lo sube con el teclado en vez de
/// dejarlo tapado. Cerrado el teclado, respeta la barra de gestos.
class RedactorDeMensaje extends StatelessWidget {
  final TextEditingController controlador;

  /// «Escríbele al médico», «Escribe tu mensaje».
  final String pista;

  /// El tope del servidor para un mensaje.
  final int maximo;

  /// Si el teclado está abierto. Se mide fuera del `Scaffold`: dentro del
  /// cuerpo ya viene descontado.
  final bool tecladoAbierto;

  final bool enviando;

  /// Qué se está haciendo al enviar: «Subiendo el archivo…».
  final String? progreso;

  final String? error;

  /// Qué no se puede hacer sin red, en una frase.
  final String sinRed;

  /// El archivo elegido para el próximo mensaje, ya pintado.
  final Widget? adjunto;

  final VoidCallback alAdjuntar;
  final VoidCallback alEnviar;

  /// La tecla de acción del teclado: `send` envía con ella; `newline` (por
  /// defecto) salta de línea.
  final TextInputAction accionDelTeclado;

  const RedactorDeMensaje({
    super.key,
    required this.controlador,
    required this.pista,
    required this.maximo,
    required this.tecladoAbierto,
    required this.enviando,
    required this.sinRed,
    required this.alAdjuntar,
    required this.alEnviar,
    this.progreso,
    this.error,
    this.adjunto,
    this.accionDelTeclado = TextInputAction.newline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + (tecladoAbierto ? 0 : context.margenInferiorDelSistema),
      ),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border(
          top: BorderSide(
            color: AppColors.primarioClaro.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: ConRed(
        builder: (context, hayRed) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              _Nota(error!, color: AppColors.errorTexto, negrita: true),
            if (!hayRed) _Nota(sinRed, color: AppColors.alertaTexto),
            if (adjunto != null) ...[adjunto!, const SizedBox(height: 8)],
            if (progreso != null)
              _Nota(progreso!, color: AppColors.textoSecundario),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('boton-adjuntar-mensaje'),
                  tooltip: 'Adjuntar un archivo',
                  onPressed: enviando ? null : alAdjuntar,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: AppColors.primarioClaro,
                  ),
                ),
                Expanded(
                  child: _Campo(
                    controlador: controlador,
                    pista: pista,
                    maximo: maximo,
                    habilitado: !enviando,
                    accion: accionDelTeclado,
                    alEnviar: hayRed ? alEnviar : null,
                  ),
                ),
                const SizedBox(width: 6),
                enviando
                    ? const _Enviando()
                    : IconButton.filled(
                        key: const Key('boton-enviar-mensaje'),
                        tooltip: 'Enviar',
                        onPressed: hayRed ? alEnviar : null,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.acento,
                          disabledBackgroundColor: AppColors.acento.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea de texto sobre el campo: un error, sin red, el progreso.
class _Nota extends StatelessWidget {
  final String texto;
  final Color color;
  final bool negrita;

  const _Nota(this.texto, {required this.color, this.negrita = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: negrita ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controlador;
  final String pista;
  final int maximo;
  final bool habilitado;
  final TextInputAction accion;

  /// Con la tecla «enviar» del teclado; `null` sin red.
  final VoidCallback? alEnviar;

  const _Campo({
    required this.controlador,
    required this.pista,
    required this.maximo,
    required this.habilitado,
    required this.accion,
    required this.alEnviar,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color, [double ancho = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return TextField(
      key: const Key('campo-mensaje'),
      controller: controlador,
      enabled: habilitado,
      minLines: 1,
      maxLines: 5,
      maxLength: maximo,
      textInputAction: accion,
      onSubmitted: accion == TextInputAction.send && alEnviar != null
          ? (_) => alEnviar!()
          : null,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(color: AppColors.texto, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: pista,
        hintStyle: const TextStyle(color: AppColors.textoPista),
        counterText: '',
        filled: true,
        fillColor: AppColors.campo,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: borde(AppColors.bordeCampo),
        enabledBorder: borde(AppColors.bordeCampo),
        focusedBorder: borde(AppColors.acentoClaro, 1.6),
      ),
    );
  }
}

class _Enviando extends StatelessWidget {
  const _Enviando();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.acentoClaro,
        ),
      ),
    );
  }
}
