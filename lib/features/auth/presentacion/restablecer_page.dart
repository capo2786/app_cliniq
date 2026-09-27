// lib/features/auth/presentacion/restablecer_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
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
import '../providers/restablecer_cubit.dart';
import 'widgets/fortaleza_contrasena.dart';
import 'widgets/recuperar_contrasena.dart';
import 'widgets/resultado_de_enlace.dart';

/// A donde lleva el enlace «Restablecer contraseña» del correo
/// (`/restablecer?token=…`), dentro de la aplicación.
///
/// La contraseña nueva con su confirmación, con la regla de la clínica
/// (`seguridad.passwordMinimo`) y la barra de fortaleza del registro. Si el
/// enlace venció, se dice y se ofrece pedir otro.
class RestablecerPage extends StatelessWidget {
  final String token;
  final AuthService? servicio;

  const RestablecerPage({super.key, required this.token, this.servicio});

  @override
  Widget build(BuildContext context) {
    final auth = servicio ?? Servicios.auth;

    return BlocProvider(
      create: (_) => RestablecerCubit(auth, token),
      child: BlocConsumer<RestablecerCubit, RestablecerState>(
        listenWhen: (antes, ahora) => !antes.listo && ahora.listo,
        // El gestor de contraseñas del teléfono ofrece guardar la nueva.
        listener: (_, _) => TextInput.finishAutofillContext(),
        buildWhen: (antes, ahora) => antes.listo != ahora.listo,
        builder: (context, state) {
          if (token.trim().isEmpty) return _EnlaceIncompleto(servicio: auth);
          if (state.listo) return const _ContrasenaGuardada();
          return _FormularioContrasenaNueva(servicio: auth);
        },
      ),
    );
  }
}

/// El marco de las tres vistas: la cabecera y el fondo de la aplicación.
class _Marco extends StatelessWidget {
  final List<Widget> children;
  final Widget? barra;

  const _Marco({required this.children, this.barra});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Contraseña nueva')),
      bottomNavigationBar: barra,
      body: FondoDegradado(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: context.margenDeScroll(superior: 28),
          children: children,
        ),
      ),
    );
  }
}

class _EnlaceIncompleto extends StatelessWidget {
  final AuthService servicio;

  const _EnlaceIncompleto({required this.servicio});

  @override
  Widget build(BuildContext context) {
    return _Marco(
      children: [
        const EntradaAnimada(
          child: ResultadoDeEnlace(
            icono: Icons.link_off_rounded,
            color: AppColors.alerta,
            titulo: 'Enlace incompleto',
            texto:
                'Abre el enlace completo que llegó a tu correo, o pide uno '
                'nuevo.',
          ),
        ),
        const SizedBox(height: 26),
        BotonPrincipal(
          key: const Key('boton-pedir-otro-enlace'),
          texto: 'Pedir un enlace nuevo',
          icono: Icons.mail_outline_rounded,
          onPressed: () => mostrarRecuperarContrasena(
            context,
            correoInicial: '',
            servicio: servicio,
          ),
        ),
      ],
    );
  }
}

class _ContrasenaGuardada extends StatelessWidget {
  const _ContrasenaGuardada();

  @override
  Widget build(BuildContext context) {
    return _Marco(
      children: [
        const EntradaAnimada(
          child: ResultadoDeEnlace(
            icono: Icons.verified_user_rounded,
            color: AppColors.exito,
            titulo: 'Contraseña actualizada',
            texto: 'Ya puedes ingresar con tu contraseña nueva.',
          ),
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

class _FormularioContrasenaNueva extends StatefulWidget {
  final AuthService servicio;

  const _FormularioContrasenaNueva({required this.servicio});

  @override
  State<_FormularioContrasenaNueva> createState() =>
      _FormularioContrasenaNuevaState();
}

class _FormularioContrasenaNuevaState
    extends State<_FormularioContrasenaNueva> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();
  final FocusNode _focoConfirmar = FocusNode();

  bool _ver = false;
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    // La barra de fortaleza sigue a la contraseña letra por letra.
    _nueva.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nueva.dispose();
    _confirmar.dispose();
    _focoConfirmar.dispose();
    super.dispose();
  }

  void _guardar() {
    cerrarTeclado();
    setState(() => _intentado = true);
    if (_formKey.currentState?.validate() != true) return;

    context.read<RestablecerCubit>().guardar(_nueva.text);
  }

  void _pedirOtroEnlace() => mostrarRecuperarContrasena(
    context,
    correoInicial: '',
    servicio: widget.servicio,
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestablecerCubit>().state;
    final minimo = context.config.seguridad.passwordMinimo;
    final guardando = state.guardando;

    return _Marco(
      barra: BarraDeAccion(
        child: BotonPrincipal(
          key: const Key('boton-guardar-contrasena'),
          texto: 'Guardar contraseña',
          icono: Icons.check_rounded,
          cargando: guardando,
          textoCargando: 'Guardando…',
          onPressed: _guardar,
        ),
      ),
      children: [
        Form(
          key: _formKey,
          autovalidateMode: _intentado
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crea una contraseña nueva',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa al menos $minimo caracteres. Mejor si combinas '
                  'mayúsculas, números y símbolos.',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                if (state.error case final error?) ...[
                  const SizedBox(height: 16),
                  RecuadroAviso.error(
                    error,
                    key: const Key('error-restablecer'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('boton-pedir-otro-enlace'),
                      onPressed: _pedirOtroEnlace,
                      icon: const Icon(Icons.mail_outline_rounded, size: 17),
                      label: const Text('Pedir otro enlace'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.acentoSuave,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ..._campos(minimo, guardando),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _campos(int minimo, bool guardando) => [
    const EtiquetaCampo('Contraseña nueva'),
    CampoCliniq(
      key: const Key('restablecer-contrasena'),
      controller: _nueva,
      pista: 'Mínimo $minimo caracteres',
      icono: Icons.lock_outline_rounded,
      oculto: !_ver,
      habilitado: !guardando,
      accion: TextInputAction.next,
      autofill: const [AutofillHints.newPassword],
      validator: (valor) => errorDeContrasenaRegistro(valor, minimo: minimo),
      onSubmitted: (_) => _focoConfirmar.requestFocus(),
      sufijo: IconButton(
        tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
        icon: Icon(
          _ver ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textoSecundario,
          size: 21,
        ),
        onPressed: () => setState(() => _ver = !_ver),
      ),
    ),
    FortalezaDeContrasena(contrasena: _nueva.text, minimo: minimo),
    const SizedBox(height: 14),
    const EtiquetaCampo('Repítela'),
    CampoCliniq(
      key: const Key('restablecer-confirmar'),
      controller: _confirmar,
      foco: _focoConfirmar,
      pista: 'Escríbela de nuevo',
      icono: Icons.lock_reset_rounded,
      oculto: !_ver,
      habilitado: !guardando,
      accion: TextInputAction.done,
      autofill: const [AutofillHints.newPassword],
      validator: (valor) => errorDeConfirmacion(valor, _nueva.text),
      onSubmitted: (_) {
        if (!guardando) _guardar();
      },
    ),
  ];
}
