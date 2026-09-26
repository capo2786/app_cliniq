// lib/features/auth/presentacion/login_page.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app/version_instalada.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/logo_cliniq.dart';
import '../../../core/service/biometria_service.dart';
import '../../../core/servicios.dart';
import '../../../core/storage/credenciales_service.dart';
import '../../../core/tema/tokens.dart';
import '../data/acceso.dart';
import '../data/auth_service.dart';
import '../providers/auth_bloc.dart';
import '../providers/auth_event.dart';
import '../providers/auth_state.dart';
import 'widgets/paso_codigo.dart';
import 'widgets/recuperar_contrasena.dart';

/// La pantalla de acceso.
///
/// Es la primera que se ve, así que carga con la impresión de toda la
/// aplicación: el logotipo de verdad, la tarjeta de vidrio sobre el fondo,
/// el contenido que sube al abrir y un solo botón con el color de la acción.
///
/// Quien ya entró en este teléfono ve arriba su correo y un botón para
/// entrar con huella o rostro; el formulario queda debajo para cuando la
/// huella no responda o entre otra persona.
class LoginPage extends StatefulWidget {
  /*
   * De dónde salen las credenciales guardadas, la huella y la recuperación.
   *
   * Se pueden sustituir en las pruebas: sin esto, montar la pantalla
   * preguntaría al llavero y al lector de huellas del sistema, que en una
   * prueba no existen.
   */
  final CredencialesService? credenciales;
  final BiometriaService? biometria;
  final AuthService? servicio;

  const LoginPage({
    super.key,
    this.credenciales,
    this.biometria,
    this.servicio,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late final CredencialesService _credenciales =
      widget.credenciales ?? Servicios.credenciales;
  late final BiometriaService _biometria =
      widget.biometria ?? Servicios.biometria;

  bool _verPassword = false;
  bool _formularioEnviado = false;
  bool _verificandoHuella = false;

  ModoDeAcceso _modo = ModoDeAcceso.primeraVez;
  CredencialesLocales? _guardadas;

  @override
  void initState() {
    super.initState();
    unawaited(_cargarGuardadas());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _cargarGuardadas() async {
    final guardadas = await _credenciales.leer();
    final disponible = guardadas != null && await _biometria.disponible();
    final activa = await _credenciales.biometriaActiva();

    if (!mounted) return;

    final modo = AccesoRapido.decidir(
      hayCredenciales: guardadas != null,
      biometriaDisponible: disponible,
      biometriaActiva: activa,
    );

    if (AccesoRapido.precargaCorreo(modo) && _email.text.isEmpty) {
      _email.text = guardadas?.email ?? '';
    }

    setState(() {
      _guardadas = guardadas;
      _modo = modo;
    });
  }

  /// Entra con la huella y las credenciales guardadas: la contraseña sale
  /// del llavero solo después de que el teléfono verificó a la persona.
  Future<void> _entrarConHuella() async {
    final guardadas = _guardadas;
    if (guardadas == null || _verificandoHuella) return;

    setState(() => _verificandoHuella = true);

    final verificado = await _biometria.verificar(
      'Verifica tu identidad para entrar a Cliniq',
    );

    if (!mounted) return;

    setState(() => _verificandoHuella = false);

    if (!verificado) return;

    FocusManager.instance.primaryFocus?.unfocus();

    context.read<AuthBloc>().add(
      AuthLoginSolicitado(email: guardadas.email, password: guardadas.password),
    );
  }

  /// Olvida las credenciales guardadas: va a entrar otra persona.
  Future<void> _usarOtraCuenta() async {
    await _credenciales.borrar();

    if (!mounted) return;

    _email.clear();
    _password.clear();

    setState(() {
      _guardadas = null;
      _modo = ModoDeAcceso.primeraVez;
    });
  }

  void _enviar() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _formularioEnviado = true);

    if (_formKey.currentState?.validate() != true) return;

    context.read<AuthBloc>().add(
      AuthLoginSolicitado(email: _email.text, password: _password.text),
    );
  }

  Future<void> _recuperar() async {
    await mostrarRecuperarContrasena(
      context,
      correoInicial: _email.text.trim(),
      servicio: widget.servicio ?? Servicios.auth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.fondoProfundo,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.fondoProfundo,
              AppColors.fondoDegradadoMedio,
              AppColors.fondo,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(child: _FondoDeAcceso()),
            SafeArea(
              child: BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthAutenticado) {
                    TextInput.finishAutofillContext();
                    _password.clear();
                  }
                },
                builder: (context, state) {
                  final cargando = state is AuthCargando;

                  return _contenido(state: state, cargando: cargando);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido({required AuthState state, required bool cargando}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: LayoutBuilder(
        builder: (context, limites) {
          final alturaMinima = limites.maxHeight > 48
              ? limites.maxHeight - 48
              : 0.0;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: alturaMinima),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: EntradaAnimada(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Marca(),
                        const SizedBox(height: 24),
                        if (state is AuthNoAutenticado &&
                            state.aviso != null) ...[
                          RecuadroAviso.alerta(
                            state.aviso!,
                            icono: Icons.timer_off_outlined,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_modo == ModoDeAcceso.huella &&
                            state is! AuthRequiere2fa) ...[
                          _accesoConHuella(cargando: cargando),
                          const SizedBox(height: 16),
                        ],
                        _TarjetaDeVidrio(
                          child: state is AuthRequiere2fa
                              ? PasoCodigo(estado: state)
                              : _formulario(state: state, cargando: cargando),
                        ),
                        const SizedBox(height: 18),
                        const _SinCuenta(),
                        const SizedBox(height: 18),
                        const PieDeVersion(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formulario({required AuthState state, required bool cargando}) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _formularioEnviado
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accede a tu cuenta',
                        style: TextStyle(
                          color: AppColors.texto,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Ingresa con el correo que registraste en la '
                        'clínica.',
                        style: TextStyle(
                          color: AppColors.textoSecundario,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                _InsigniaSegura(),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: state is AuthError
                  ? Padding(
                      key: ValueKey(state.mensaje),
                      padding: const EdgeInsets.only(top: 18),
                      child: _ErrorDeAcceso(
                        estado: state,
                        alRecuperar: _recuperar,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('sin-error')),
            ),
            const SizedBox(height: 22),
            const EtiquetaCampo('Correo electrónico'),
            CampoCliniq(
              key: const Key('campo-correo'),
              controller: _email,
              pista: 'tucorreo@ejemplo.com',
              icono: Icons.alternate_email_rounded,
              habilitado: !cargando,
              teclado: TextInputType.emailAddress,
              accion: TextInputAction.next,
              autofill: const [AutofillHints.email, AutofillHints.username],
              validator: (valor) {
                final texto = valor?.trim() ?? '';
                if (texto.isEmpty) return 'Ingresa tu correo electrónico.';
                if (!texto.contains('@') || !texto.contains('.')) {
                  return 'Ese correo no parece válido.';
                }
                return null;
              },
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 18),
            const EtiquetaCampo('Contraseña'),
            CampoCliniq(
              key: const Key('campo-contrasena'),
              controller: _password,
              pista: 'Tu contraseña',
              icono: Icons.lock_outline_rounded,
              oculto: !_verPassword,
              habilitado: !cargando,
              accion: TextInputAction.done,
              autofill: const [AutofillHints.password],
              validator: (valor) => (valor == null || valor.isEmpty)
                  ? 'Ingresa tu contraseña.'
                  : null,
              onSubmitted: (_) {
                if (!cargando) _enviar();
              },
              sufijo: IconButton(
                tooltip: _verPassword
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                icon: Icon(
                  _verPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textoSecundario,
                  size: 21,
                ),
                onPressed: cargando
                    ? null
                    : () => setState(() => _verPassword = !_verPassword),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: cargando ? null : _recuperar,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.acentoSuave,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            BotonPrincipal(
              key: const Key('boton-entrar'),
              texto: 'Entrar a Cliniq',
              icono: Icons.login_rounded,
              cargando: cargando,
              textoCargando: 'Verificando…',
              onPressed: _enviar,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                cargando
                    ? 'Estamos validando tu acceso. Puede tardar unos '
                          'segundos si la red es inestable.'
                    : 'Tu contraseña no se guarda en el teléfono salvo para '
                          'el acceso con huella, y siempre cifrada.',
                key: ValueKey(cargando),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Entrar con la huella, para quien ya entró en este teléfono.
  ///
  /// Es lo que se ve primero porque es lo que se hace todos los días.
  Widget _accesoConHuella({required bool cargando}) {
    final ocupado = cargando || _verificandoHuella;
    final correo = _guardadas?.email ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarioClaro.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primarioClaro.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        children: [
          Text(
            correo.isEmpty ? 'Bienvenido de nuevo' : correo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: _verificandoHuella ? 'Verificando…' : 'Entrar con tu huella',
            icono: Icons.fingerprint_rounded,
            cargando: _verificandoHuella,
            textoCargando: 'Verificando…',
            onPressed: ocupado ? null : _entrarConHuella,
            alto: 54,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: ocupado ? null : _usarOtraCuenta,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textoSecundario,
              minimumSize: const Size(0, 34),
            ),
            child: const Text(
              'Entrar con otra cuenta',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// El logotipo, el nombre y para qué sirve la aplicación.
class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primarioClaro.withValues(alpha: 0.24),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.acentoClaro,
                size: 15,
              ),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'PORTAL DEL PACIENTE',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // El logotipo de verdad, el mismo del arranque y del icono: un icono
        // genérico haría que la pantalla pareciera de cualquier aplicación.
        const InsigniaCliniq(tamano: 96),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (limites) =>
              AppGradientes.nombreDeMarca.createShader(limites),
          child: const Text(
            'Cliniq',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Tus citas médicas, en tu mano',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de vidrio: deja ver el fondo desenfocado por debajo.
///
/// Un bloque opaco sobre el degradado partía la pantalla en dos; el
/// desenfoque la mantiene como una sola pieza y hace que el formulario
/// parezca apoyado encima, que es donde tiene que estar la atención.
class _TarjetaDeVidrio extends StatelessWidget {
  final Widget child;

  const _TarjetaDeVidrio({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.sombra,
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Por qué no se pudo entrar. Con la cuenta bloqueada, además, qué hacer.
class _ErrorDeAcceso extends StatelessWidget {
  final AuthError estado;
  final VoidCallback alRecuperar;

  const _ErrorDeAcceso({required this.estado, required this.alRecuperar});

  @override
  Widget build(BuildContext context) {
    if (!estado.bloqueada) return RecuadroAviso.error(estado.mensaje);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.alerta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.alerta.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                color: AppColors.alerta,
                size: 20,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Cuenta bloqueada por 15 minutos',
                  style: TextStyle(
                    color: AppColors.alertaTexto,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            estado.mensaje,
            style: const TextStyle(
              color: AppColors.alertaTextoFuerte,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Es una protección contra intentos de adivinar tu contraseña. '
            'Si no la recuerdas, pide un enlace para crear una nueva.',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: alRecuperar,
              icon: const Icon(Icons.mail_outline_rounded, size: 17),
              label: const Text('Recuperar contraseña'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.acentoSuave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No hay registro público: las cuentas las crea la clínica.
class _SinCuenta extends StatelessWidget {
  const _SinCuenta();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: AppColors.textoSecundario,
          size: 16,
        ),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            '¿No tienes cuenta? Pide tu registro en la clínica',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsigniaSegura extends StatelessWidget {
  const _InsigniaSegura();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.exito.withValues(alpha: 0.2)),
      ),
      child: const Tooltip(
        message: 'Conexión y credenciales protegidas',
        child: Icon(Icons.shield_outlined, color: AppColors.exito, size: 21),
      ),
    );
  }
}

/// Los halos y la rejilla tenue del fondo del acceso.
class _FondoDeAcceso extends StatelessWidget {
  const _FondoDeAcceso();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -90,
          child: _Halo(
            tamano: 310,
            color: AppColors.primarioClaro.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -110,
          child: _Halo(
            tamano: 340,
            color: AppColors.acento.withValues(alpha: 0.14),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _Rejilla())),
      ],
    );
  }
}

class _Halo extends StatelessWidget {
  final double tamano;
  final Color color;

  const _Halo({required this.tamano, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _Rejilla extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = AppColors.primarioClaro.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const paso = 34.0;

    for (double x = 0; x <= size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pintura);
    }

    for (double y = 0; y <= size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pintura);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
