// lib/features/navegacion/presentacion/receptor_de_enlaces.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/presentacion/confirmar_correo_page.dart';
import '../../auth/presentacion/restablecer_page.dart';
import '../dominio/enlaces_entrantes.dart';

/// Recibe los enlaces de los correos que abren la aplicación (App Links en
/// Android, Universal Links en iOS) y abre su pantalla encima de lo que se
/// esté viendo: confirmar el correo o crear la contraseña nueva.
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

    final ruta = MaterialPageRoute<void>(
      builder: (_) => switch (enlace) {
        EnlaceConfirmarCorreo(:final token) => ConfirmarCorreoPage(
          token: token,
        ),
        EnlaceRestablecer(:final token) => RestablecerPage(token: token),
      },
    );

    _ultimo = enlace;
    _rutaDelUltimo = ruta;
    unawaited(Navigator.of(context).push(ruta));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
