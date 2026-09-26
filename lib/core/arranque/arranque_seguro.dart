import 'dart:async';

import 'package:flutter/material.dart';

import '../tema/tokens.dart';

/// Que un fallo al arrancar se vea, en lugar de dejar la pantalla en negro.
///
/// En release una excepción antes de `runApp` no se ve en ninguna parte: la
/// aplicación se queda en el arranque sin decir nada y el reporte que llega
/// es «no abre». Aquí:
///
/// 1. Todo lo que pasa antes de pintar se intenta, pero **nada puede impedir
///    que la aplicación abra**: si los recordatorios no se pueden preparar,
///    se abre igual.
/// 2. Los errores se escriben en el registro del sistema (`adb logcat`).
/// 3. Un error de construcción pinta una pantalla que dice qué pasó.

/// Lo que se recogió durante el arranque, para poder enseñarlo.
final List<String> fallosDeArranque = <String>[];

/// Corre un paso del arranque sin que su fallo impida abrir la aplicación.
Future<void> intentar(String queSeHacia, Future<void> Function() paso) async {
  try {
    await paso();
  } catch (error, pila) {
    registrarFallo(queSeHacia, error, pila);
  }
}

void registrarFallo(String donde, Object error, StackTrace? pila) {
  final mensaje = 'Cliniq · fallo en $donde: $error';

  fallosDeArranque.add(mensaje);

  // `debugPrint` calla en release; esto tiene que llegar a logcat siempre.
  // ignore: avoid_print
  print(mensaje);
  if (pila != null) {
    // ignore: avoid_print
    print(pila.toString());
  }
}

/// Deja enganchados los tres sitios por donde se escapa un error.
void vigilarErrores() {
  FlutterError.onError = (detalles) {
    FlutterError.presentError(detalles);
    registrarFallo('la interfaz', detalles.exception, detalles.stack);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, pila) {
    registrarFallo('la plataforma', error, pila);
    return true;
  };

  ErrorWidget.builder = (detalles) =>
      PantallaDeFallo(mensaje: detalles.exceptionAsString());
}

/// Lo que se enseña cuando algo se rompe de verdad.
class PantallaDeFallo extends StatelessWidget {
  const PantallaDeFallo({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppColors.fondo,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.alerta,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'La aplicación no pudo abrir esta pantalla',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Muestra este mensaje al equipo de soporte de la clínica.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                mensaje,
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
