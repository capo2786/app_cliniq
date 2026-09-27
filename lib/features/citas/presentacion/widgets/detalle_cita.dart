import 'package:flutter/material.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../agendar/presentacion/agendar_page.dart';
import '../../data/models/cita.dart';
import '../../dominio/reglas_citas.dart';
import '../../dominio/videoconsulta.dart';
import '../estilos_cita.dart';
import 'cancelar_cita.dart';
import 'hoja_calendario.dart';
import 'tarjeta_cita.dart';
import 'videoconsulta.dart';

/// Abre el detalle de una cita en una hoja inferior.
Future<void> mostrarDetalleCita(BuildContext context, Cita cita) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => DetalleCita(cita: cita, contextoPadre: context),
  );
}

/// Todo lo de una cita, y lo que se puede hacer con ella.
///
/// «Reprogramar» y «Cancelar» solo aparecen en una cita pendiente con al
/// menos 12 horas por delante; si faltan menos, se explica por qué no están
/// en vez de esconderlos sin decir nada.
class DetalleCita extends StatelessWidget {
  final Cita cita;

  /// El contexto de quien abrió la hoja: al reprogramar se cierra la hoja y
  /// se navega desde ahí.
  final BuildContext contextoPadre;

  const DetalleCita({
    super.key,
    required this.cita,
    required this.contextoPadre,
  });

  Future<void> _reprogramar(BuildContext context) async {
    final navegador = Navigator.of(contextoPadre);
    Navigator.of(context).pop();

    await navegador.push(
      MaterialPageRoute<void>(builder: (_) => AgendarPage(reprogramar: cita)),
    );
  }

  Future<void> _cancelar(BuildContext context) async {
    final cancelada = await mostrarCancelarCita(context, cita);

    if (cancelada == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = Servicios.reloj.ahora();
    final cambiable = puedeCambiar(cita, ahora);
    final sinCambios = motivoSinCambios(cita, ahora);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, desplazamiento) => ListView(
        controller: desplazamiento,
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bordeCampo,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              HojaCalendario(fecha: cita.inicio, ancho: 70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FormatoFecha.diaLargo(cita.inicio),
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FormatoFecha.rangoHoras(cita.inicio, cita.fin),
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pastilla(
                          texto: cita.estado.nombre,
                          color: cita.estado.color,
                          icono: cita.estado.icono,
                        ),
                        if (cita.pendiente)
                          Pastilla(
                            texto: cuentaRegresiva(cita, ahora),
                            color: AppColors.acentoClaro,
                            icono: Icons.hourglass_bottom_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Detalle'),
          TarjetaTranslucida(
            child: Column(
              children: [
                FilaDato(
                  icono: Icons.person_outline_rounded,
                  rotulo: 'Paciente',
                  valor: cita.paraDependiente
                      ? '${cita.pacienteNombre ?? 'Dependiente'} (dependiente)'
                      : cita.pacienteNombre,
                ),
                FilaDato(
                  icono: Icons.medical_information_outlined,
                  rotulo: 'Médico',
                  valor: [
                    cita.medicoVisible,
                    if (cita.especialidad != null) cita.especialidad!,
                  ].join(' · '),
                ),
                FilaDato(
                  icono: cita.tipo.icono,
                  rotulo: 'Modalidad',
                  valor: '${cita.tipo.nombre} · ${cita.tipo.descripcion}',
                ),
                FilaDato(
                  icono: Icons.notes_rounded,
                  rotulo: 'Motivo de consulta',
                  valor: cita.motivo,
                ),
                if (cita.estado == EstadoCita.cancelada)
                  FilaDato(
                    icono: Icons.cancel_outlined,
                    rotulo: 'Motivo de la cancelación',
                    valor: cita.motivoCancelacion,
                  ),
              ],
            ),
          ),
          if (cita.pendiente) ...[
            const SizedBox(height: 16),
            ConsejosDePreparacion(consejos: consejosPara(cita.tipo)),
          ],
          // La sala sigue abierta una hora después del fin, así que también
          // se ofrece desde el historial mientras tanto.
          if (estadoDeSala(cita, ahora)
              case EstadoSala.porAbrir || EstadoSala.abierta) ...[
            const SizedBox(height: 16),
            const EtiquetaSeccion('Videoconsulta'),
            BotonVideoconsulta(cita: cita),
          ],
          const SizedBox(height: 22),
          if (cambiable)
            ConRed(
              builder: (context, hayRed) => Column(
                children: [
                  if (!hayRed) ...[
                    const RecuadroAviso.alerta(
                      'Sin conexión: para reprogramar o cancelar necesitas '
                      'Internet.',
                      icono: Icons.cloud_off_outlined,
                    ),
                    const SizedBox(height: 12),
                  ],
                  BotonPrincipal(
                    texto: 'Reprogramar',
                    icono: Icons.edit_calendar_rounded,
                    onPressed: hayRed ? () => _reprogramar(context) : null,
                  ),
                  const SizedBox(height: 10),
                  BotonSecundario(
                    texto: 'Cancelar cita',
                    icono: Icons.event_busy_rounded,
                    color: AppColors.peligroSuave,
                    onPressed: hayRed ? () => _cancelar(context) : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Puedes cambiarla hasta $horasMinimasCambio horas antes.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoTenue,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            )
          else if (sinCambios != null)
            RecuadroAviso.alerta(sinCambios, icono: Icons.lock_clock_outlined),
        ],
      ),
    );
  }
}
