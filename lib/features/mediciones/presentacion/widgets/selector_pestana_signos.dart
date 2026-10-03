// lib/features/mediciones/presentacion/widgets/selector_pestana_signos.dart

import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';

/// Las dos pestañas de «Mis signos vitales».
enum PestanaSignos { tendencias, registro }

/// «Tendencias» y «Registro», con la elegida resaltada.
class SelectorDePestanaSignos extends StatelessWidget {
  final PestanaSignos elegida;
  final ValueChanged<PestanaSignos> alElegir;

  const SelectorDePestanaSignos({
    super.key,
    required this.elegida,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    Widget pestana(PestanaSignos p, String texto, IconData icono) {
      final activa = p == elegida;
      return Expanded(
        child: Semantics(
          selected: activa,
          button: true,
          child: InkWell(
            key: Key('pestana-${p.name}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => alElegir(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: activa ? AppColors.tarjeta : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icono,
                    size: 18,
                    color: activa ? AppColors.texto : AppColors.textoTenue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    texto,
                    style: TextStyle(
                      color: activa ? AppColors.texto : AppColors.textoTenue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeCampo),
      ),
      child: Row(
        children: [
          pestana(
            PestanaSignos.tendencias,
            'Tendencias',
            Icons.insights_rounded,
          ),
          pestana(PestanaSignos.registro, 'Registro', Icons.list_alt_rounded),
        ],
      ),
    );
  }
}
