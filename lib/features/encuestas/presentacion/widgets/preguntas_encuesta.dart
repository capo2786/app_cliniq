// lib/features/encuestas/presentacion/widgets/preguntas_encuesta.dart

import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_encuesta.dart';

/// Una pregunta de la encuesta: el enunciado, lo que se elige y, si se
/// intentó enviar sin contestarla, qué falta.
class PreguntaEncuesta extends StatelessWidget {
  final String enunciado;
  final Widget respuesta;
  final String? error;

  const PreguntaEncuesta({
    super.key,
    required this.enunciado,
    required this.respuesta,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enunciado,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        respuesta,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              color: AppColors.errorTexto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// De 1 a 5 estrellas, con lo que quiere decir la elegida.
class EstrellasEncuesta extends StatelessWidget {
  final int valor;
  final ValueChanged<int>? alElegir;

  const EstrellasEncuesta({super.key, required this.valor, this.alElegir});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var n = 1; n <= puntuacionMaxima; n++)
          Semantics(
            button: true,
            selected: valor == n,
            label:
                '${n == 1 ? '1 estrella' : '$n estrellas'}: '
                '${textoPuntuacion[n]}',
            child: IconButton(
              key: Key('estrella-$n'),
              onPressed: alElegir == null ? null : () => alElegir!(n),
              iconSize: 36,
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
              icon: Icon(
                n <= valor ? Icons.star_rounded : Icons.star_outline_rounded,
                color: n <= valor ? AppColors.alerta : AppColors.textoTenue,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            valor == 0 ? 'Toca una estrella' : textoPuntuacion[valor] ?? '',
            style: TextStyle(
              color: valor == 0 ? AppColors.textoTenue : AppColors.texto,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// La escala del 0 al 10 del NPS; la elegida, con el color de su categoría.
class EscalaRecomendacion extends StatelessWidget {
  final int? valor;
  final ValueChanged<int>? alElegir;

  const EscalaRecomendacion({super.key, required this.valor, this.alElegir});

  static Color _color(int n) => switch (categoriaNps(n)) {
    CategoriaNps.detractor => AppColors.peligro,
    CategoriaNps.pasivo => AppColors.alerta,
    CategoriaNps.promotor => AppColors.exito,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 0; n <= recomendacionMaxima; n++)
              _Numero(
                numero: n,
                elegido: valor == n,
                color: _color(n),
                alTocar: alElegir == null ? null : () => alElegir!(n),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Expanded(child: Text('0 · Nada probable', style: _estiloExtremo)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '10 · Muy probable',
                textAlign: TextAlign.end,
                style: _estiloExtremo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const TextStyle _estiloExtremo = TextStyle(
    color: AppColors.textoTenue,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}

class _Numero extends StatelessWidget {
  final int numero;
  final bool elegido;
  final Color color;
  final VoidCallback? alTocar;

  const _Numero({
    required this.numero,
    required this.elegido,
    required this.color,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegido,
      child: InkWell(
        key: Key('recomendacion-$numero'),
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: elegido ? color : AppColors.tarjetaPlana,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: elegido ? color : AppColors.bordeCampo),
          ),
          child: Text(
            '$numero',
            style: TextStyle(
              color: elegido ? Colors.white : AppColors.textoSuave,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
