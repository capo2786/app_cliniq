// lib/features/auth/presentacion/confirmar_correo_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../data/auth_service.dart';
import '../dominio/registro.dart';
import '../providers/confirmar_correo_cubit.dart';
import 'widgets/resultado_de_enlace.dart';

/// A donde lleva el enlace «Confirmar mi correo» del correo de registro
/// (`/confirmar-correo?token=…`), dentro de la aplicación.
///
/// Confirma sola al abrirse y dice cómo salió: con la cuenta activa,
/// «Ingresar»; con un enlace vencido o ya usado, deja pedir otro sin volver
/// a registrarse.
class ConfirmarCorreoPage extends StatelessWidget {
  final String token;
  final AuthService? servicio;

  const ConfirmarCorreoPage({super.key, required this.token, this.servicio});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ConfirmarCorreoCubit(servicio ?? Servicios.auth, token)..confirmar(),
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(title: const Text('Confirmar correo')),
        body: FondoDegradado(
          child: BlocBuilder<ConfirmarCorreoCubit, ConfirmarCorreoState>(
            builder: (context, state) => ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: context.margenDeScroll(superior: 28),
              children: [
                EntradaAnimada(
                  key: ValueKey(state.etapa),
                  child: _contenido(context, state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, ConfirmarCorreoState state) {
    switch (state.etapa) {
      case EtapaConfirmacion.confirmando:
        return const CargandoCentro(mensaje: 'Confirmando tu correo…');
      case EtapaConfirmacion.confirmada:
        return _Confirmada(mensaje: state.mensaje);
      case EtapaConfirmacion.fallo:
        return _Fallo(mensaje: state.mensaje);
      case EtapaConfirmacion.enlaceInvalido:
      case EtapaConfirmacion.enlaceIncompleto:
        return _EnlaceQueNoSirve(estado: state);
    }
  }
}

class _Confirmada extends StatelessWidget {
  final String mensaje;

  const _Confirmada({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultadoDeEnlace(
          icono: Icons.verified_rounded,
          color: AppColors.exito,
          titulo: '¡Listo! Tu cuenta está activa',
          texto: mensaje.isEmpty ? mensajeCorreoConfirmado : mensaje,
        ),
        const SizedBox(height: 26),
        BotonPrincipal(
          key: const Key('boton-ingresar'),
          texto: 'Ingresar',
          icono: Icons.login_rounded,
          onPressed: () => volverAlAcceso(context),
        ),
      ],
    );
  }
}

/// No se pudo hablar con el servidor (o falló él): el mismo enlace sirve.
class _Fallo extends StatelessWidget {
  final String mensaje;

  const _Fallo({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultadoDeEnlace(
          icono: Icons.cloud_off_rounded,
          color: AppColors.alerta,
          titulo: 'No pudimos confirmar tu correo',
          texto: mensaje,
        ),
        const SizedBox(height: 26),
        BotonPrincipal(
          key: const Key('boton-reintentar-confirmacion'),
          texto: 'Reintentar',
          icono: Icons.refresh_rounded,
          onPressed: () => context.read<ConfirmarCorreoCubit>().confirmar(),
        ),
        const SizedBox(height: 8),
        const _VolverAlIngreso(),
      ],
    );
  }
}

/// El enlace venció, ya se usó o llegó incompleto: se puede pedir otro.
class _EnlaceQueNoSirve extends StatelessWidget {
  final ConfirmarCorreoState estado;

  const _EnlaceQueNoSirve({required this.estado});

  @override
  Widget build(BuildContext context) {
    final incompleto = estado.etapa == EtapaConfirmacion.enlaceIncompleto;
    final reenviadoA = estado.reenviadoA;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultadoDeEnlace(
          icono: Icons.link_off_rounded,
          color: AppColors.alerta,
          titulo: incompleto
              ? 'El enlace está incompleto'
              : 'El enlace no es válido o ya venció',
          texto: incompleto
              ? 'Abre el enlace completo que llegó a tu correo o pide uno '
                    'nuevo.'
              : estado.mensaje.isNotEmpty
              ? estado.mensaje
              : 'Puede que ya lo hayas usado: en ese caso, intenta ingresar. '
                    'Si no, pide un enlace nuevo.',
        ),
        const SizedBox(height: 22),
        if (reenviadoA != null)
          RecuadroAviso(
            mensaje:
                'Si hay una cuenta pendiente con $reenviadoA, te enviamos un '
                'enlace nuevo. Revisa también el correo no deseado.',
            icono: Icons.mark_email_read_outlined,
            color: AppColors.exito,
            colorTexto: AppColors.texto,
          )
        else
          _PedirOtroEnlace(estado: estado),
        const SizedBox(height: 8),
        const _VolverAlIngreso(),
      ],
    );
  }
}

class _PedirOtroEnlace extends StatefulWidget {
  final ConfirmarCorreoState estado;

  const _PedirOtroEnlace({required this.estado});

  @override
  State<_PedirOtroEnlace> createState() => _PedirOtroEnlaceState();
}

class _PedirOtroEnlaceState extends State<_PedirOtroEnlace> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _correo = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  void _enviar() {
    cerrarTeclado();
    if (_formKey.currentState?.validate() != true) return;

    context.read<ConfirmarCorreoCubit>().reenviar(_correo.text);
  }

  @override
  Widget build(BuildContext context) {
    final enviando = widget.estado.reenviando;
    final error = widget.estado.errorReenvio;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EtiquetaCampo('Tu correo'),
          CampoCliniq(
            key: const Key('campo-correo-reenvio'),
            controller: _correo,
            pista: 'nombre@correo.com',
            icono: Icons.alternate_email_rounded,
            habilitado: !enviando,
            teclado: TextInputType.emailAddress,
            accion: TextInputAction.send,
            autofill: const [AutofillHints.email],
            validator: errorDeCorreoRegistro,
            onSubmitted: (_) => _enviar(),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            RecuadroAviso.error(error),
          ],
          const SizedBox(height: 16),
          BotonPrincipal(
            key: const Key('boton-enviar-enlace-nuevo'),
            texto: 'Enviar un enlace nuevo',
            icono: Icons.forward_to_inbox_rounded,
            cargando: enviando,
            textoCargando: 'Enviando…',
            onPressed: _enviar,
          ),
        ],
      ),
    );
  }
}

class _VolverAlIngreso extends StatelessWidget {
  const _VolverAlIngreso();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const Key('boton-volver-al-ingreso'),
        onPressed: () => volverAlAcceso(context),
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        label: const Text('Volver al ingreso'),
        style: TextButton.styleFrom(foregroundColor: AppColors.acentoSuave),
      ),
    );
  }
}
