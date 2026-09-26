import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../tema/tokens.dart';

/// Qué versión de la aplicación es esta, en una cadena: `1.0.0 (1)`.
///
/// Es la primera pregunta de soporte, y buscarla en los ajustes del teléfono
/// es un trámite que nadie sabe hacer. Se pregunta una vez y se recuerda.
class VersionInstalada {
  static String? _recordada;

  static Future<String> leer() async {
    final guardada = _recordada;
    if (guardada != null) return guardada;

    try {
      final info = await PackageInfo.fromPlatform();
      _recordada = componerVersion(
        info.version.trim(),
        info.buildNumber.trim(),
      );
    } catch (_) {
      // Un dato de apoyo no puede romper una pantalla.
      _recordada = '';
    }

    return _recordada!;
  }

  /// Olvida lo recordado. Para las pruebas.
  static void olvidar() => _recordada = null;
}

/// «1.0.0 (1)», o la versión sola si no hay compilación.
String componerVersion(String version, String compilacion) {
  if (version.isEmpty) return '';

  return compilacion.isEmpty ? 'v$version' : 'v$version ($compilacion)';
}

/// El pie con la versión instalada, para el acceso y el perfil.
class PieDeVersion extends StatefulWidget {
  final String leyenda;

  const PieDeVersion({
    super.key,
    this.leyenda = 'Tus datos de salud viajan protegidos con tu sesión',
  });

  @override
  State<PieDeVersion> createState() => _PieDeVersionState();
}

class _PieDeVersionState extends State<PieDeVersion> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    final version = await VersionInstalada.leer();

    if (mounted && version.isNotEmpty) setState(() => _version = version);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              color: AppColors.textoTenue,
              size: 15,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                widget.leyenda,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_version != null) ...[
          const SizedBox(height: 6),
          Text(
            'Cliniq $_version',
            style: const TextStyle(
              color: AppColors.textoTenue,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
