// lib/features/navegacion/presentacion/receptor_de_enlaces.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/avisos.dart';
import '../../auth/presentacion/registro_page.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_state.dart';
import '../../clinicas/presentacion/logo_de_clinica_publica.dart';
import '../../clinicas/providers/clinica_cubit.dart';

import '../../auth/presentacion/confirmar_correo_page.dart';
import '../../auth/presentacion/restablecer_page.dart';
import '../dominio/enlaces_entrantes.dart';

/// Recibe los enlaces de los correos que abren la aplicación (App Links en
/// Android, Universal Links en iOS) y abre su pantalla encima de lo que se
/// esté viendo: confirmar el correo, crear la contraseña nueva o crear una
/// cuenta en la clínica del enlace (`/registro?clinica=CODIGO`).
///
/// [enlaces] es el flujo de `app_links` (el primero, si la aplicación se
/// abrió con un enlace, y los que lleguen después); sin él, no escucha
/// nada. Va debajo del navegador de la aplicación y después de tener los
/// datos de la clínica, que las dos pantallas necesitan.
class ReceptorDeEnlaces extends StatefulWidget {
  final Stream<Uri>? enlaces;
  final Widget child;

  const ReceptorDeEnlaces({
    super.key,
    required this.enlaces,
    required this.child,
  });

  @override
  State<ReceptorDeEnlaces> createState() => _ReceptorDeEnlacesState();
}

class _ReceptorDeEnlacesState extends State<ReceptorDeEnlaces> {
  StreamSubscription<Uri>? _suscripcion;

  /// El último enlace abierto y su pantalla: si el mismo enlace llega otra
  /// vez con su pantalla todavía abierta, no se abre dos veces (el segundo
  /// intento de confirmar diría que el enlace ya se usó).
  EnlaceEntrante? _ultimo;
  Route<void>? _rutaDelUltimo;

  @override
  void initState() {
    super.initState();
    _suscripcion = widget.enlaces?.listen(_abrir, onError: (Object _) {});
  }

  @override
  void dispose() {
    unawaited(_suscripcion?.cancel());
    super.dispose();
  }

  void _abrir(Uri direccion) {
    final enlace = leerEnlaceEntrante(direccion);
    if (enlace == null || !mounted) return;

    if (enlace == _ultimo && (_rutaDelUltimo?.isActive ?? false)) return;

    if (enlace is EnlaceRegistro) {
      unawaited(_abrirRegistro(enlace));
      return;
    }

    _empujar(
      enlace,
      (_) => switch (enlace) {
        EnlaceConfirmarCorreo(:final token) => ConfirmarCorreoPage(
          token: token,
        ),
        EnlaceRestablecer(:final token) => RestablecerPage(token: token),
        EnlaceRegistro() => const RegistroPage(),
      },
    );
  }

  void _empujar(EnlaceEntrante enlace, WidgetBuilder pantalla) {
    final ruta = MaterialPageRoute<void>(builder: pantalla);

    _ultimo = enlace;
    _rutaDelUltimo = ruta;
    unawaited(Navigator.of(context).push(ruta));
  }

  /// El registro de la clínica del enlace: se busca su código, se elige y
  /// se abre el registro (ya con su marca y sus documentos legales). Con la
  /// sesión abierta no: la clínica de la sesión es la que manda.
  Future<void> _abrirRegistro(EnlaceRegistro enlace) async {
    if (_conSesion()) {
      mostrarAviso(
        context,
        'Ya tienes tu sesión abierta. Para crear una cuenta en otra clínica, '
        'cierra sesión primero.',
      );
      return;
    }

    final clinicas = clinicaCubitSiHay(context);
    if (enlace.codigo.isNotEmpty && clinicas != null) {
      final resultado = await clinicas.buscar(enlace.codigo);
      if (!mounted) return;

      if (resultado is! CodigoEncontrado) {
        mostrarAviso(
          context,
          mensajeDeBusqueda(resultado, enlace.codigo) ?? '',
          error: true,
        );
        return;
      }

      await clinicas.elegir(resultado.clinica);
      if (!mounted) return;
    }

    _empujar(enlace, (_) => const RegistroPage());
  }

  bool _conSesion() {
    try {
      return context.read<AuthBloc>().state is AuthAutenticado;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
