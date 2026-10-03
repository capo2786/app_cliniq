// lib/features/mediciones/escaner/widgets/paso_resultado.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/medicion.dart';
import '../../dominio/destinos_medico.dart';
import '../../dominio/reglas_mediciones.dart';
import '../escaner_cubit.dart';
import '../motor_signos_camara.dart';
import 'pasos_comunes.dart';

/// El resultado: la FC con su calidad, la FR si aplica, quién lo calculó,
/// el momento y «Guardar», «Enviar a mi médico» o «Descartar».
class PasoResultado extends StatelessWidget {
  final EscanerState state;
  final List<DestinoMedico> destinos;

  const PasoResultado({super.key, required this.state, required this.destinos});

  Future<void> _enviarAlMedico(BuildContext context) async {
    final cubit = context.read<EscanerCubit>();
    final destino = destinos.length == 1
        ? destinos.single
        : await showModalBottomSheet<DestinoMedico>(
            context: context,
            backgroundColor: AppColors.superficie,
            showDragHandle: true,
            builder: (contexto) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const Text(
                    '¿A cuál de tus atenciones la adjuntamos?',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final d in destinos)
                    ListTile(
                      key: Key('destino-${d.citaId ?? d.consultaId}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        d.citaId != null
                            ? Icons.videocam_outlined
                            : Icons.forum_outlined,
                        color: AppColors.primarioClaro,
                      ),
                      title: Text(
                        d.titulo,
                        style: const TextStyle(color: AppColors.texto),
                      ),
                      subtitle: d.detalle == null || d.detalle!.isEmpty
                          ? null
                          : Text(
                              d.detalle!,
                              style: const TextStyle(
                                color: AppColors.textoSecundario,
                              ),
                            ),
                      onTap: () => Navigator.of(contexto).pop(d),
                    ),
                ],
              ),
            ),
          );
    if (destino != null) await cubit.guardar(destino: destino);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final r = state.resultado!;
    final color = colorDeCalidad(r.calidad);
    final contextos = contextosDelTipo(TipoMedicion.fc);

    return CuerpoConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-guardar'),
            texto: 'Guardar en mis signos vitales',
            icono: Icons.save_alt_rounded,
            cargando: state.guardando,
            textoCargando: 'Guardando…',
            onPressed: () => cubit.guardar(),
          ),
          const SizedBox(height: 10),
          BotonSecundario(
            key: const Key('escaner-enviar-medico'),
            texto: 'Enviar a mi médico',
            icono: Icons.send_rounded,
            onPressed: destinos.isEmpty || state.guardando
                ? null
                : () => _enviarAlMedico(context),
          ),
          TextButton(
            key: const Key('escaner-descartar'),
            onPressed: state.guardando ? null : cubit.descartar,
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
      children: [
        TarjetaTranslucida(
          tinte: color,
          child: Column(
            children: [
              Text(
                '${r.fc} lpm',
                key: const Key('escaner-fc'),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Pulso (frecuencia cardiaca)',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Pastilla(
                    key: const Key('escaner-nivel'),
                    texto: nombreDelNivel(r.nivel),
                    color: color,
                    icono: Icons.signal_cellular_alt_rounded,
                  ),
                  const Pastilla(
                    texto: 'Experimental · referencial',
                    color: AppColors.alerta,
                    icono: Icons.science_outlined,
                  ),
                ],
              ),
              if (r.fr != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Respiraciones: ${r.fr} por minuto (aproximado)',
                  key: const Key('escaner-fr'),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (r.vfc != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Variabilidad del pulso: SDNN ${r.vfc!.sdnn.round()} ms · '
                  'RMSSD ${r.vfc!.rmssd.round()} ms',
                  key: const Key('escaner-vfc'),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                r.origen == OrigenAnalisis.servidor
                    ? 'Analizado en el servidor (experimental)'
                    : 'Calculado en el teléfono',
                key: const Key('escaner-origen'),
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (r.nivel == NivelCalidad.baja) ...[
          const SizedBox(height: 12),
          const RecuadroAviso.alerta(
            'La señal no fue buena: toma este valor con mucha cautela y, si '
            'puedes, repite la medición.',
          ),
        ],
        for (final advertencia in r.advertencias) ...[
          const SizedBox(height: 10),
          RecuadroAviso.informacion(advertencia, icono: Icons.info_outline),
        ],
        const SizedBox(height: 20),
        const EtiquetaSeccion('¿Cómo estabas?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in contextos)
              ChipDeOpcion(
                key: Key('contexto-${c.codigo}'),
                texto: nombreDelContexto(c),
                elegido: state.contexto == c,
                onTap: () =>
                    cubit.elegirContexto(state.contexto == c ? null : c),
              ),
          ],
        ),
        if (destinos.isEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Para enviarla a tu médico necesitas una cita de telemedicina '
            'próxima o una consulta en línea abierta.',
            key: Key('escaner-sin-destino'),
            style: TextStyle(color: AppColors.textoTenue, fontSize: 12),
          ),
        ],
        if (state.errorAlGuardar != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.error(state.errorAlGuardar!),
        ],
        const LineaPrivacidad(),
      ],
    );
  }
}
