import 'dart:async';

import 'package:flutter/material.dart';

import '../../red/estado_de_la_red.dart';
import '../../tema/tokens.dart';

/// Avisa de que no hay salida a Internet **antes** de que haga falta.
///
/// Si hay conexión no ocupa ni un píxel. Si no la hay, dice por qué —no es
/// lo mismo estar en modo avión que en un wifi que no sale— y qué se puede
/// hacer igual: ver lo guardado. Los botones que necesitan red se apagan
/// con [ConRed].
class AvisoSinConexion extends StatefulWidget {
  /// Qué se puede hacer igual sin conexión en esta pantalla.
  final String queSePuedeHacer;

  final SondeoDeRed? sondeo;

  const AvisoSinConexion({
    super.key,
    this.queSePuedeHacer =
        'Mostramos lo último que guardamos en este teléfono. Agendar, '
        'cancelar o cambiar algo necesita conexión.',
    this.sondeo,
  });

  @override
  State<AvisoSinConexion> createState() => _AvisoSinConexionState();
}

class _AvisoSinConexionState extends State<AvisoSinConexion> {
  late final SondeoDeRed _sondeo = widget.sondeo ?? SondeoDeRed();

  @override
  void initState() {
    super.initState();

    // Se pregunta al abrir; si hay una respuesta reciente, se reutiliza.
    unawaited(_sondeo.estado());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoDeLaRed?>(
      valueListenable: _sondeo.actual,
      builder: (context, estado, _) {
        // Mientras se comprueba no se dice nada: un cartel que aparece y
        // desaparece al segundo se lee como un parpadeo.
        if (estado == null || estado.hayInternet) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.alerta.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.alerta.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.alerta),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado.explicacion,
                      style: const TextStyle(
                        color: AppColors.alertaTexto,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.queSePuedeHacer,
                      style: const TextStyle(
                        color: AppColors.alertaTextoFuerte,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reconstruye lo de dentro cuando cambia la conexión.
///
/// Es lo que apaga los botones que necesitan red: sin conexión, «Agendar» o
/// «Cancelar cita» solo llevarían a un error; apagados, con el cartel de
/// arriba explicando por qué, no engañan a nadie.
class ConRed extends StatelessWidget {
  final Widget Function(BuildContext context, bool hayRed) builder;
  final SondeoDeRed? sondeo;

  const ConRed({super.key, required this.builder, this.sondeo});

  @override
  Widget build(BuildContext context) {
    final sondeo = this.sondeo ?? SondeoDeRed();

    return ValueListenableBuilder<EstadoDeLaRed?>(
      valueListenable: sondeo.actual,
      builder: (context, estado, _) =>
          builder(context, estado?.hayInternet ?? true),
    );
  }
}
