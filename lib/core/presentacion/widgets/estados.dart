import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// Lo que se enseña cuando no hay nada que enseñar.
///
/// Siempre dice por qué está vacío y, si se puede, qué hacer: una lista en
/// blanco sin explicación se lee como un error.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final String? accion;
  final VoidCallback? alPulsar;

  /// Sin él, el de la marca (primarioClaro).
  final Color? color;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.accion,
    this.alPulsar,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primarioClaro;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaciado.xxl),
      decoration: BoxDecoration(
        color: AppColors.tarjetaPlana,
        borderRadius: AppRadio.dePanel,
        border: Border.all(color: AppColors.bordeCampo),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icono, color: color, size: 30),
          ),
          const SizedBox(height: AppEspaciado.l),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (accion != null && alPulsar != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: alPulsar,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(accion!),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acentoClaro,
                side: BorderSide(
                  color: AppColors.acento.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Algo falló al cargar: se dice qué y se ofrece reintentar.
class EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback? alReintentar;

  const EstadoError({super.key, required this.mensaje, this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.cloud_off_rounded,
      titulo: 'No pudimos cargar esto',
      descripcion: mensaje,
      accion: alReintentar == null ? null : 'Reintentar',
      alPulsar: alReintentar,
      color: AppColors.alerta,
    );
  }
}

/// Una rueda centrada con su explicación.
class CargandoCentro extends StatelessWidget {
  final String mensaje;

  const CargandoCentro({super.key, this.mensaje = 'Cargando…'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: AppColors.acentoClaro,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un recuadro de aviso dentro de una pantalla: error, alerta o dato.
class RecuadroAviso extends StatelessWidget {
  final String mensaje;
  final IconData icono;

  /// `null` en el de información: el tono de la marca en uso, que sale de
  /// la configuración de la clínica y no es constante.
  final Color? color;
  final Color colorTexto;

  const RecuadroAviso({
    super.key,
    required this.mensaje,
    this.icono = Icons.error_outline_rounded,
    this.color = AppColors.peligro,
    this.colorTexto = AppColors.errorTextoClaro,
  });

  /// Un error, en rojo.
  const RecuadroAviso.error(this.mensaje, {super.key})
    : icono = Icons.error_outline_rounded,
      color = AppColors.peligro,
      colorTexto = AppColors.errorTextoClaro;

  /// Una advertencia, en ámbar.
  const RecuadroAviso.alerta(
    this.mensaje, {
    super.key,
    this.icono = Icons.info_outline_rounded,
  }) : color = AppColors.alerta,
       colorTexto = AppColors.alertaTexto;

  /// Un dato que conviene saber, en el tono de la marca.
  const RecuadroAviso.informacion(
    this.mensaje, {
    super.key,
    this.icono = Icons.info_outline_rounded,
  }) : color = null,
       colorTexto = AppColors.textoSuave;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primarioClaro;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: colorTexto,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
