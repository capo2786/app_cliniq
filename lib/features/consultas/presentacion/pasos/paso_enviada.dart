import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_consultas.dart';
import '../../providers/nueva_consulta_state.dart';
import '../detalle_consulta_page.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../citas/dominio/reglas_citas.dart' show horas;

/// El final: la consulta salió, con su número y hasta cuándo responde el
/// médico.
class PasoEnviada extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoEnviada({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final consulta = state.enviada;
    final vence = consulta?.venceEn;

    return EntradaAnimada(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.exito.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.exito.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.exito,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Consulta enviada!',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (consulta != null && consulta.codigo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              consulta.codigo,
              style: const TextStyle(
                color: AppColors.acentoSuave,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            vence == null
                ? 'El médico tiene '
                      '${horas(context.config.telemedicina.horasRespuesta)} '
                      'para responderte. Te avisaremos por correo.'
                : '${consulta?.medicoVisible ?? 'El médico'} tiene hasta el '
                      '${momentoLegible(vence).toLowerCase()} para '
                      'responderte. Te avisaremos por correo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          if (consulta != null) ...[
            BotonPrincipal(
              texto: 'Ver la consulta',
              icono: Icons.forum_outlined,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => DetalleConsultaPage(consultaId: consulta.id),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          BotonSecundario(
            texto: 'Volver a mis consultas',
            icono: Icons.list_alt_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
