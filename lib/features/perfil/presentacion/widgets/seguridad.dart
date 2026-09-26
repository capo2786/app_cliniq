import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/tema/tokens.dart';
import '../../providers/perfil_cubit.dart';

/// Abre la hoja para cambiar la contraseña.
Future<void> mostrarCambiarContrasena(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<PerfilCubit>(),
      child: const _CambiarContrasena(),
    ),
  );
}

class _CambiarContrasena extends StatefulWidget {
  const _CambiarContrasena();

  @override
  State<_CambiarContrasena> createState() => _CambiarContrasenaState();
}

class _CambiarContrasenaState extends State<_CambiarContrasena> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _actual = TextEditingController();
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  bool _ver = false;
  int? _secuenciaPrevia;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_formKey.currentState?.validate() != true) return;

    final cubit = context.read<PerfilCubit>();
    _secuenciaPrevia = cubit.state.operacion?.secuencia;
    _enviado = true;
    setState(() => _error = null);

    cubit.cambiarContrasena(actual: _actual.text, nueva: _nueva.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PerfilCubit, PerfilState>(
      listenWhen: (antes, ahora) =>
          _enviado && ahora.operacion?.secuencia != _secuenciaPrevia,
      listener: (context, state) {
        _enviado = false;
        final operacion = state.operacion;
        if (operacion == null) return;

        if (operacion.exito) {
          // El aviso se da desde aquí: el perfil está tapado por esta hoja
          // y no lo daría.
          mostrarAviso(context, operacion.mensaje);
          Navigator.of(context).pop();
        } else {
          setState(() => _error = operacion.mensaje);
        }
      },
      builder: (context, state) {
        final error = _error;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            22 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Usa al menos 8 caracteres. Si entras con huella, se '
                    'actualiza sola.',
                    style: TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.errorTexto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const EtiquetaCampo('Contraseña actual'),
                  CampoCliniq(
                    controller: _actual,
                    pista: 'La que usas hoy',
                    icono: Icons.lock_outline_rounded,
                    oculto: !_ver,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Escribe tu contraseña actual.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Contraseña nueva'),
                  CampoCliniq(
                    controller: _nueva,
                    pista: 'Mínimo 8 caracteres',
                    icono: Icons.lock_reset_rounded,
                    oculto: !_ver,
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Debe tener al menos 8 caracteres.';
                      }
                      if (v == _actual.text) {
                        return 'Tiene que ser distinta de la actual.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Confírmala'),
                  CampoCliniq(
                    controller: _confirmar,
                    pista: 'Escríbela de nuevo',
                    icono: Icons.lock_reset_rounded,
                    oculto: !_ver,
                    validator: (v) => v != _nueva.text
                        ? 'Las contraseñas no coinciden.'
                        : null,
                  ),
                  CheckboxListTile(
                    value: _ver,
                    onChanged: (v) => setState(() => _ver = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Mostrar contraseñas',
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BotonPrincipal(
                    texto: 'Cambiar contraseña',
                    icono: Icons.check_rounded,
                    cargando: state.guardando,
                    textoCargando: 'Guardando…',
                    onPressed: _guardar,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pide la contraseña para activar o desactivar la verificación en dos
/// pasos. Devuelve la contraseña escrita, o `null` si se cancela.
Future<String?> pedirContrasenaPara2fa(
  BuildContext context, {
  required bool activar,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoContrasena(activar: activar),
  );
}

class _DialogoContrasena extends StatefulWidget {
  final bool activar;

  const _DialogoContrasena({required this.activar});

  @override
  State<_DialogoContrasena> createState() => _DialogoContrasenaState();
}

class _DialogoContrasenaState extends State<_DialogoContrasena> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _password.text;
    if (texto.isNotEmpty) Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.activar
            ? 'Activar verificación en dos pasos'
            : 'Desactivar verificación en dos pasos',
        style: const TextStyle(
          color: AppColors.texto,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.activar
                ? 'Cada vez que entres te enviaremos un código a tu correo. '
                      'Confirma con tu contraseña.'
                : 'Dejarás de recibir el código al entrar. Confirma con tu '
                      'contraseña.',
            style: const TextStyle(color: AppColors.textoSuave, height: 1.4),
          ),
          const SizedBox(height: 14),
          CampoCliniq(
            controller: _password,
            pista: 'Tu contraseña',
            icono: Icons.lock_outline_rounded,
            oculto: true,
            onSubmitted: (_) => _confirmar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.acento),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
