// lib/features/mediciones/presentacion/envio_de_pendientes.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/red/estado_de_la_red.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_state.dart';
import '../data/cola_mediciones.dart';

/// Envía las mediciones que quedaron en el teléfono sin red: al entrar, al
/// volver a la aplicación y en cuanto vuelve la conexión. No pinta nada.
///
/// Va en `main.dart`, debajo de la sesión. Lo pendiente es de quien entró:
/// sin sesión no se envía nada (y al cerrar sesión se borra).
class EnvioDeMedicionesPendientes extends StatefulWidget {
  final ColaMediciones cola;
  final SondeoDeRed red;
  final Widget child;

  const EnvioDeMedicionesPendientes({
    super.key,
    required this.cola,
    required this.red,
    required this.child,
  });

  @override
  State<EnvioDeMedicionesPendientes> createState() =>
      _EnvioDeMedicionesPendientesState();
}

class _EnvioDeMedicionesPendientesState
    extends State<EnvioDeMedicionesPendientes>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.red.actual.addListener(_alCambiarLaRed);
    // Si ya hay sesión al montarse (la restauró el arranque), de una vez.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviar());
  }

  @override
  void dispose() {
    widget.red.actual.removeListener(_alCambiarLaRed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _enviar() {
    if (!mounted) return;
    final usuario = context.read<AuthBloc>().usuario;
    if (usuario != null) unawaited(widget.cola.enviarPendientes(usuario.uid));
  }

  void _alCambiarLaRed() {
    if (widget.red.actual.value?.hayInternet == true) _enviar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enviar();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (antes, ahora) =>
          antes is! AuthAutenticado && ahora is AuthAutenticado,
      listener: (context, _) => _enviar(),
      child: widget.child,
    );
  }
}
