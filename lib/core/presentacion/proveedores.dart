// lib/core/presentacion/proveedores.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Leer un bloc o un servicio que puede no estar.
extension ProveedoresOpcionales on BuildContext {
  /// El [T] de más arriba, o `null` si no hay ninguno (sin escuchar sus
  /// cambios).
  ///
  /// Para lo que una pantalla usa si está pero no necesita: la campana a la
  /// que avisa la lista de avisos, las pendientes del inicio a las que avisa
  /// una encuesta, el nombre de la sesión para la sala de video. Así la
  /// pantalla también se monta suelta (en una prueba) sin armar todo el
  /// árbol de la aplicación.
  T? leerSiHay<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
