import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/margenes.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/fondo_app.dart';
import '../../../../core/tema/tokens.dart';
import '../../providers/registro_bloc.dart';

/// «Revisa tu correo»: la cuenta está creada y falta abrir el enlace.
///
/// «Reenviar enlace» pide otro (`POST /auth/registro/reenviar`) y se apaga
/// los segundos que diga la clínica (`seguridad.reenvioSegundos`).
/// «Volver a ingresar» —y el botón atrás— vuelven al acceso con el correo
/// ya escrito.
class RevisaTuCorreo extends StatelessWidget {
  const RevisaTuCorreo({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistroBloc>().state;
    final correo = state.correoRegistrado ?? '';

    void volver() => Navigator.of(context).pop(correo);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) volver();
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(title: const Text('Revisa tu correo')),
        body: FondoDegradado(
          child: ListView(
            padding: context.margenDeScroll(superior: 28),
            children: [
              EntradaAnimada(child: _Explicacion(correo: correo)),
              const SizedBox(height: 22),
              if (state.avisoReenvio case final aviso?) ...[
                RecuadroAviso(
                  mensaje: aviso,
                  icono: Icons.mark_email_read_outlined,
                  color: AppColors.exito,
                  colorTexto: AppColors.texto,
                ),
                const SizedBox(height: 14),
              ],
              if (state.errorReenvio case final error?) ...[
                RecuadroAviso.error(error),
                const SizedBox(height: 14),
              ],
              BotonSecundario(
                key: const Key('boton-reenviar-registro'),
                texto: state.reenviando
                    ? 'Enviando…'
                    : state.espera > 0
                    ? 'Reenviar en ${state.espera} s'
                    : 'Reenviar enlace',
                icono: Icons.forward_to_inbox_rounded,
                onPressed: state.puedeReenviar
                    ? () => context.read<RegistroBloc>().add(
                        const RegistroReenvioPedido(),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              BotonPrincipal(
                key: const Key('boton-volver-a-ingresar'),
                texto: 'Volver a ingresar',
                icono: Icons.login_rounded,
                onPressed: volver,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  final String correo;

  const _Explicacion({required this.correo});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      color: AppColors.textoSuave,
      fontSize: 14,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.exito.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.exito.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            color: AppColors.exito,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Revisa tu correo para confirmar tu cuenta',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: estilo,
            children: [
              const TextSpan(text: 'Te enviamos un enlace a '),
              TextSpan(
                text: correo,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const TextSpan(
                text:
                    '. Ábrelo para activar tu cuenta; hasta entonces no podrás '
                    'ingresar. Si no lo ves en unos minutos, revisa la carpeta '
                    'de correo no deseado.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
