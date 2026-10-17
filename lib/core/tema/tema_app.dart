import 'package:flutter/material.dart';

import 'tokens.dart';

/// El tema de Material para Cliniq: oscuro siempre, con los colores de la
/// marca. Las pantallas casi no dependen de él —pintan con los tokens—, pero
/// los diálogos, los selectores de fecha y los campos del sistema sí.
ThemeData temaCliniq() {
  final esquema =
      ColorScheme.fromSeed(
        seedColor: AppColors.primario,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.acento,
        onPrimary: AppColors.textoSobreAccion,
        secondary: AppColors.primarioClaro,
        surface: AppColors.superficie,
        onSurface: AppColors.texto,
        error: AppColors.peligroSuave,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.fondo,
    canvasColor: AppColors.fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.superficie,
      foregroundColor: AppColors.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: AppColors.texto,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.superficie),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.tarjeta,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? AppColors.acento
            : Colors.transparent,
      ),
      side: BorderSide(color: AppColors.primarioClaro, width: 1.6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.textoSecundario,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? AppColors.acento
            : AppColors.tarjeta,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.acentoClaro,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.acentoClaro,
      selectionColor: AppColors.acento.withValues(alpha: 0.35),
      selectionHandleColor: AppColors.acentoClaro,
    ),
  );
}
