// lib/features/clinicas/presentacion/hoja_elegir_clinica.dart

import 'package:flutter/material.dart';

import '../../../core/tema/tokens.dart';
import '../dominio/clinica.dart';
import 'logo_de_clinica_publica.dart';

/// La hoja que sale al entrar cuando el correo tiene cuenta en varias
/// clínicas (409 `EMPRESA_AMBIGUA`). Devuelve la elegida, o `null` si se
/// cerró sin elegir.
Future<Clinica?> elegirClinica(BuildContext context, List<Clinica> clinicas) {
  return showModalBottomSheet<Clinica>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => HojaElegirClinica(clinicas: clinicas),
  );
}

class HojaElegirClinica extends StatelessWidget {
  final List<Clinica> clinicas;

  const HojaElegirClinica({super.key, required this.clinicas});

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: alto),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AsaDeHoja(),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: const Text(
                  '¿En qué clínica quieres entrar?',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu correo tiene una cuenta en cada una de estas clínicas. '
                'Elige la tuya; la recordaremos para la próxima vez.',
                style: TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: clinicas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _OpcionDeClinica(
                    clinica: clinicas[i],
                    alElegir: () => Navigator.of(context).pop(clinicas[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionDeClinica extends StatelessWidget {
  final Clinica clinica;
  final VoidCallback alElegir;

  const _OpcionDeClinica({required this.clinica, required this.alElegir});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Entrar a ${clinica.nombre}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.tarjeta,
        borderRadius: AppRadio.deTarjeta,
        child: InkWell(
          key: Key('clinica-${clinica.codigo}'),
          borderRadius: AppRadio.deTarjeta,
          onTap: alElegir,
          child: Padding(
            padding: const EdgeInsets.all(AppEspaciado.m),
            child: Row(
              children: [
                LogoDeClinicaPublica(clinica: clinica, tamano: 48),
                const SizedBox(width: AppEspaciado.m),
                Expanded(
                  child: Text(
                    clinica.nombre,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primarioClaro,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La rayita de arriba de las hojas, para arrastrarlas.
class AsaDeHoja extends StatelessWidget {
  const AsaDeHoja({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.bordeCampo,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
