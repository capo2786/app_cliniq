import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../providers/auth_bloc.dart';
import '../../providers/auth_event.dart';
import '../../providers/auth_state.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/formato/fechas.dart';

/// El segundo paso del acceso: el código de seis dígitos del correo.
///
/// Vive dentro de la misma tarjeta de vidrio que el formulario: es el mismo
/// acceso, un paso más adelante, y no una pantalla nueva que desoriente.
class PasoCodigo extends StatefulWidget {
  final AuthRequiere2fa estado;

  const PasoCodigo({super.key, required this.estado});

  @override
  State<PasoCodigo> createState() => _PasoCodigoState();
}

class _PasoCodigoState extends State<PasoCodigo> {
  final TextEditingController _codigo = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _enviar() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_formKey.currentState?.validate() != true) return;

    context.read<AuthBloc>().add(AuthCodigoEnviado(_codigo.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final digitos = context.config.seguridad.otpDigitos;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.acentoClaro,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verificación en dos pasos',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Te enviamos un código de $digitos dígitos a ${estado.destino}. '
            'Escríbelo para terminar de entrar. Vence en '
            '${minutos(context.config.seguridad.otpMinutos)}.',
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (estado.error != null) ...[
            const SizedBox(height: 14),
            RecuadroAviso.error(estado.error!),
          ],
          const SizedBox(height: 18),
          const EtiquetaCampo('Código de verificación'),
          CampoCliniq(
            key: const Key('campo-codigo'),
            controller: _codigo,
            pista: '0' * digitos,
            icono: Icons.pin_outlined,
            habilitado: !estado.enviando,
            teclado: TextInputType.number,
            accion: TextInputAction.done,
            autofill: const [AutofillHints.oneTimeCode],
            formatos: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(digitos),
            ],
            validator: (valor) => (valor?.trim().length ?? 0) == digitos
                ? null
                : 'El código tiene $digitos dígitos.',
            onSubmitted: (_) => _enviar(),
          ),
          const SizedBox(height: 20),
          BotonPrincipal(
            texto: 'Verificar y entrar',
            icono: Icons.verified_user_outlined,
            cargando: estado.enviando,
            textoCargando: 'Verificando código…',
            onPressed: _enviar,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: estado.enviando
                  ? null
                  : () => context.read<AuthBloc>().add(
                      const AuthCodigoCancelado(),
                    ),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Volver e intentar de nuevo'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
