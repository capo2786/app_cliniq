// lib/features/mediciones/presentacion/widgets/partes_mediciones.dart

import 'package:flutter/material.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/cola_mediciones.dart';
import '../../data/models/medicion.dart';
import '../../dominio/reglas_mediciones.dart';

IconData iconoDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => Icons.favorite_rounded,
  TipoMedicion.fr => Icons.air_rounded,
  TipoMedicion.pa => Icons.speed_rounded,
  TipoMedicion.spo2 => Icons.water_drop_outlined,
  TipoMedicion.temp => Icons.thermostat_rounded,
  TipoMedicion.glucosa => Icons.bloodtype_outlined,
  TipoMedicion.peso => Icons.monitor_weight_outlined,
};

Color colorDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => AppColors.peligroSuave,
  TipoMedicion.fr => AppColors.celeste,
  TipoMedicion.pa => AppColors.acentoClaro,
  TipoMedicion.spo2 => AppColors.menta,
  TipoMedicion.temp => AppColors.ambar,
  TipoMedicion.glucosa => AppColors.violeta,
  TipoMedicion.peso => AppColors.primarioClaro,
};

/// La insignia del método: «Cámara · experimental», «Aparato de casa» o
/// «A mano».
Widget insigniaDelMetodo(MetodoMedicion metodo) => metodo.esCamara
    ? const Pastilla(
        texto: 'Cámara · experimental',
        color: AppColors.alerta,
        icono: Icons.science_outlined,
      )
    : Pastilla(
        texto: metodo == MetodoMedicion.manual ? 'A mano' : 'Aparato de casa',
        color: AppColors.primarioClaro,
        icono: metodo == MetodoMedicion.manual
            ? Icons.back_hand_outlined
            : Icons.devices_other_rounded,
      );

Color _colorDelNivel(NivelCalidad nivel) => switch (nivel) {
  NivelCalidad.buena => AppColors.exito,
  NivelCalidad.regular => AppColors.alerta,
  NivelCalidad.baja => AppColors.peligroSuave,
};

/// Las insignias de una medición: el método (el origen), la calidad si es
/// de la cámara, si se envió al médico y si el médico la usó. Las comparten
/// la lista y el detalle.
List<Widget> insigniasDeMedicion(Medicion m) {
  final calidad = m.calidad;
  return [
    insigniaDelMetodo(m.metodo),
    if (m.metodo.esCamara && calidad != null)
      Pastilla(
        texto: nombreDelNivel(nivelDeCalidad(calidad)),
        color: _colorDelNivel(nivelDeCalidad(calidad)),
      ),
    if (m.enviadaAlMedico)
      const Pastilla(
        texto: 'Enviada a tu médico',
        color: AppColors.celeste,
        icono: Icons.send_rounded,
      ),
    if (m.usada)
      const Pastilla(
        texto: 'Usada en una atención',
        color: AppColors.exito,
        icono: Icons.check_rounded,
      ),
  ];
}

/// La flecha que dice que una tarjeta se abre.
const Widget _flechaDeAbrir = Padding(
  padding: EdgeInsets.only(top: 10, left: 2),
  child: Icon(
    Icons.chevron_right_rounded,
    color: AppColors.textoTenue,
    size: 22,
  ),
);

/// «Hoy», «Ayer» o «Lunes 28 de septiembre»: el día de una medición en la
/// hora de la clínica.
String diaDeLaMedicion(DateTime medidoEn, DateTime ahora) {
  final dia = enHoraDeLaClinica(medidoEn);
  final hoy = enHoraDeLaClinica(ahora);
  final diferencia = DateTime.utc(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(DateTime.utc(dia.year, dia.month, dia.day)).inDays;
  if (diferencia == 0) return 'Hoy';
  if (diferencia == 1) return 'Ayer';
  return dia.year == hoy.year
      ? FormatoFecha.diaLargo(dia)
      : FormatoFecha.diaLargoConAnio(dia);
}

/// Una medición en la lista. Con [alAbrir], se toca para ver su detalle:
/// lleva la flecha y es un botón para los lectores de pantalla.
class TarjetaMedicion extends StatelessWidget {
  final Medicion medicion;
  final VoidCallback? alEliminar;
  final VoidCallback? alAbrir;
  final bool eliminando;

  const TarjetaMedicion({
    super.key,
    required this.medicion,
    this.alEliminar,
    this.alAbrir,
    this.eliminando = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicion;
    final color = colorDelTipo(m.tipo);
    final hora = FormatoFecha.hora(enHoraDeLaClinica(m.medidoEn));

    final tarjeta = TarjetaTranslucida(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: alAbrir,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconoDelTipo(m.tipo), color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valorDeMedicion(m),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    nombreDelTipo(m.tipo),
                    hora,
                    if (m.contexto != null) nombreDelContexto(m.contexto!),
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: insigniasDeMedicion(m),
                ),
                if (m.notas != null && !m.notas!.startsWith('motor:')) ...[
                  const SizedBox(height: 6),
                  Text(
                    m.notas!,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (alEliminar != null && !m.usada)
            eliminando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    key: Key('eliminar-${m.id}'),
                    tooltip: 'Eliminar',
                    onPressed: alEliminar,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textoTenue,
                    ),
                  ),
          if (alAbrir != null) _flechaDeAbrir,
        ],
      ),
    );

    if (alAbrir == null) return tarjeta;
    return Semantics(
      container: true,
      button: true,
      hint: 'Ver el detalle de la medición',
      child: tarjeta,
    );
  }
}

/// Un envío que espera red (o que el servidor rechazó). Con [alAbrir], se
/// toca para ver su detalle.
class TarjetaPendiente extends StatelessWidget {
  final EnvioPendiente envio;
  final VoidCallback alDescartar;
  final VoidCallback? alAbrir;

  const TarjetaPendiente({
    super.key,
    required this.envio,
    required this.alDescartar,
    this.alAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final color = envio.rechazado ? AppColors.peligroSuave : AppColors.alerta;
    final momento = envio.mediciones.first.medidoEn;
    final cuando = FormatoFecha.cortaConHora(enHoraDeLaClinica(momento));

    final tarjeta = TarjetaTranslucida(
      tinte: color,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: alAbrir,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            envio.rechazado
                ? Icons.error_outline_rounded
                : Icons.cloud_upload_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  envio.mediciones.map(valorDeMedicionNueva).join(' · '),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cuando,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  envio.rechazado
                      ? 'No se pudo guardar: ${envio.rechazo}'
                      : 'Pendiente de enviar: se enviará sola cuando vuelva la '
                            'conexión.',
                  style: TextStyle(color: color, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('descartar-${envio.idLocal}'),
            tooltip: 'Descartar',
            onPressed: alDescartar,
            icon: const Icon(Icons.close_rounded, color: AppColors.textoTenue),
          ),
          if (alAbrir != null) _flechaDeAbrir,
        ],
      ),
    );

    if (alAbrir == null) return tarjeta;
    return Semantics(
      container: true,
      button: true,
      hint: 'Ver el detalle de la medición',
      child: tarjeta,
    );
  }
}
