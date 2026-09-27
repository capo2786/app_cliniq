package ec.cliniq.sage.app

import io.flutter.embedding.android.FlutterFragmentActivity

/*
 * FlutterFragmentActivity y no FlutterActivity: `local_auth` muestra el
 * diálogo de huella con el BiometricPrompt de AndroidX, que necesita una
 * actividad de fragmentos. Con la actividad de la plantilla, el acceso con
 * huella lanza «local_auth plugin requires activity to be a
 * FragmentActivity» y el botón no hace nada.
 */
class MainActivity : FlutterFragmentActivity()
