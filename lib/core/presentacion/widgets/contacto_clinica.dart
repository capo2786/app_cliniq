// lib/core/presentacion/widgets/contacto_clinica.dart

import 'package:flutter/material.dart';

import '../../configuracion/config_publica.dart';
import '../../configuracion/en_contexto.dart';
import '../../tema/tokens.dart';
import '../enlaces.dart';

/// El teléfono y el correo de la clínica, para tocarlos y llamar o escribir.
///
/// Va donde la aplicación le dice a la persona que se comunique con la
/// clínica: «llama a la clínica» sin número no le sirve a nadie. Salen de la
/// configuración (`clinica.telefono`, `clinica.correoContacto`); si la
/// clínica no configuró ninguno de los dos, no se enseña nada.
class ContactoClinica extends StatelessWidget {
  /// Un texto antes de los datos: «Si no puedes asistir, comunícate con la
  /// clínica».
  final String? mensaje;

  /// La configuración, para usarla fuera del árbol normal (la pantalla de
  /// fallo). Sin ella se lee del contexto.
  final DatosClinica? clinica;

  const ContactoClinica({super.key, this.mensaje, this.clinica});

  @override
  Widget build(BuildContext context) {
    final datos = clinica ?? context.config.clinica;
    final telefono = datos.telefono.trim();
    final correo = datos.correoContacto.trim();

    if (telefono.isEmpty && correo.isEmpty) {
      return mensaje == null
          ? const SizedBox.shrink()
          : Text(mensaje!, style: _estiloMensaje);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mensaje != null) ...[
          Text(mensaje!, style: _estiloMensaje),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            if (telefono.isNotEmpty)
              _Enlace(
                key: const Key('contacto-telefono'),
                icono: Icons.phone_outlined,
                texto: telefono,
                alPulsar: () => llamar(context, telefono),
              ),
            if (correo.isNotEmpty)
              _Enlace(
                key: const Key('contacto-correo'),
                icono: Icons.mail_outline_rounded,
                texto: correo,
                alPulsar: () => escribirCorreo(context, correo),
              ),
          ],
        ),
      ],
    );
  }
}

const TextStyle _estiloMensaje = TextStyle(
  color: AppColors.textoSuave,
  fontSize: 12.5,
  height: 1.4,
);

class _Enlace extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alPulsar;

  const _Enlace({
    super.key,
    required this.icono,
    required this.texto,
    required this.alPulsar,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: alPulsar,
      icon: Icon(icono, size: 17),
      label: Text(
        texto,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.acentoSuave,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}

/// El número de emergencias de la configuración (`clinica.telefonoEmergencia`)
/// como botón para llamar.
class BotonEmergencia extends StatelessWidget {
  const BotonEmergencia({super.key});

  @override
  Widget build(BuildContext context) {
    final numero = context.config.clinica.telefonoEmergencia.trim();
    if (numero.isEmpty) return const SizedBox.shrink();

    return TextButton.icon(
      key: const Key('boton-emergencia'),
      onPressed: () => llamar(context, numero),
      icon: const Icon(Icons.emergency_outlined, size: 17),
      label: Text(
        'Llamar al $numero',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.peligroSuave,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
    );
  }
}
