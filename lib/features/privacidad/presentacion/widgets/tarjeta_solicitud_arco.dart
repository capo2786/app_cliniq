// lib/features/privacidad/presentacion/widgets/tarjeta_solicitud_arco.dart

import 'package:flutter/material.dart';

import '../../../../core/catalogos/catalogo_service.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/estilo_de_catalogo.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../navegacion/presentacion/enrutador.dart';
import '../../data/arco_service.dart';
import '../../dominio/reglas_arco.dart';

/// Una solicitud ARCO: qué se pidió, en qué estado está, hasta cuándo tiene
/// la clínica para responder, su respuesta y, a pedido, el historial.
class TarjetaSolicitudArco extends StatelessWidget {
  final SolicitudArco solicitud;

  const TarjetaSolicitudArco({super.key, required this.solicitud});

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    final tipo = EstiloDeCatalogo.de(
      catalogos,
      Catalogos.tipoArco,
      solicitud.tipo,
    );
    final estado = EstiloDeCatalogo.de(
      catalogos,
      Catalogos.estadoArco,
      solicitud.estado,
    );
    final ahora = Servicios.reloj.ahora();
    final respuesta = solicitud.respuesta;

    return TarjetaTranslucida(
      key: Key('solicitud-${solicitud.id}'),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pastilla(
                texto: tipo.nombre,
                color: tipo.color,
                icono: tipo.icono,
              ),
              Pastilla(
                texto: estado.nombre,
                color: estado.color,
                icono: estado.icono,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            solicitud.detalle,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enviada ${tiempoRelativo(solicitud.creadaEn, ahora)}',
            style: const TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
          ),
          if (!arcoCerrada(solicitud)) ...[
            const SizedBox(height: 8),
            _Plazo(solicitud: solicitud, ahora: ahora),
          ],
          if (respuesta != null) ...[
            const SizedBox(height: 12),
            _Respuesta(texto: respuesta, color: estado.color),
          ],
          if (solicitud.historial.isNotEmpty)
            _Historial(historial: solicitud.historial),
        ],
      ),
    );
  }
}

/// Hasta cuándo tiene la clínica para responder, o que ya se le pasó (con el
/// camino a soporte).
class _Plazo extends StatelessWidget {
  final SolicitudArco solicitud;
  final DateTime ahora;

  const _Plazo({required this.solicitud, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final vencida = arcoVencida(solicitud, Servicios.reloj.instante());
    final color = vencida ? AppColors.peligroSuave : AppColors.textoSecundario;
    final texto = textoPlazoArco(solicitud, ahora, vencida: vencida);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.schedule_rounded, size: 15, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: texto,
              children: [
                if (vencida) ...[
                  const TextSpan(text: ' Si necesitas ayuda, '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => abrirRuta(context, '/soporte'),
                      child: Text(
                        'escríbenos a soporte',
                        style: TextStyle(
                          color: AppColors.acentoSuave,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.acentoSuave,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ],
            ),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: vencida ? FontWeight.w800 : FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _Respuesta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Respuesta({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESPUESTA DE LA CLÍNICA',
            style: TextStyle(
              color: AppColors.textoTenue,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Ver el historial (3)»: cada paso con su estado, cuándo, quién y su nota.
class _Historial extends StatefulWidget {
  final List<PasoArco> historial;

  const _Historial({required this.historial});

  @override
  State<_Historial> createState() => _HistorialState();
}

class _HistorialState extends State<_Historial> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _abierto = !_abierto),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.acentoSuave,
            padding: const EdgeInsets.symmetric(vertical: 4),
            minimumSize: const Size(0, 36),
          ),
          child: Text(
            _abierto
                ? 'Ocultar el historial'
                : 'Ver el historial (${widget.historial.length})',
          ),
        ),
        if (_abierto)
          for (final paso in widget.historial)
            _PasoDelHistorial(
              paso: paso,
              estado: EstiloDeCatalogo.de(
                catalogos,
                Catalogos.estadoArco,
                paso.estado,
              ),
            ),
      ],
    );
  }
}

class _PasoDelHistorial extends StatelessWidget {
  final PasoArco paso;
  final EstiloDeCatalogo estado;

  const _PasoDelHistorial({required this.paso, required this.estado});

  @override
  Widget build(BuildContext context) {
    final cuando = FormatoFecha.cortaConHora(enHoraDeLaClinica(paso.fecha));
    final nota = paso.nota;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 9, color: estado.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estado.nombre,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  paso.porNombre.isEmpty
                      ? cuando
                      : '$cuando · ${paso.porNombre}',
                  style: const TextStyle(
                    color: AppColors.textoTenue,
                    fontSize: 11.5,
                  ),
                ),
                if (nota != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      nota,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
