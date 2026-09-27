import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_consultas.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';
import '../widgets/adjuntos.dart';
import '../widgets/campo_dinamico.dart';

/// Paso 5: las preguntas del motivo, la descripción con las propias
/// palabras y los archivos (fotos, recetas, exámenes).
///
/// Los errores se marcan recién cuando se intenta seguir: una pantalla que
/// abre llena de rojo antes de escribir nada se lee como un regaño.
class PasoFormulario extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoFormulario({super.key, required this.state});

  Future<void> _adjuntar(BuildContext context) async {
    final bloc = context.read<NuevaConsultaBloc>();
    final seleccion = await elegirArchivos(context);

    if (seleccion != null && !seleccion.vacia) {
      bloc.add(NuevaConsultaArchivosElegidos(seleccion));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();
    final motivo = state.motivo;
    final errores = state.mostrarErrores
        ? state.errores
        : const <String, String>{};
    final habilitado = !state.guardando;

    if (motivo == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TarjetaTranslucida(
          tinte: AppColors.acentoClaro,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                motivo.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (motivo.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  motivo.descripcion,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (state.medico != null) state.medico!.nombreVisible,
                  if (state.pacienteNombre.isNotEmpty)
                    'para ${state.pacienteNombre}',
                ].join(' · '),
                style: const TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (state.fijada) ...[
          const SizedBox(height: 12),
          const RecuadroAviso.informacion(
            'Es un borrador guardado: el paciente, el motivo y el médico ya '
            'no cambian. Si necesitas otros, descártalo y empieza una '
            'consulta nueva.',
            icono: Icons.edit_note_rounded,
          ),
        ],
        if (state.errorGuardar != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.error(state.errorGuardar!),
        ],
        if (errores.isNotEmpty) ...[
          const SizedBox(height: 12),
          const RecuadroAviso.alerta(
            'Revisa lo marcado en rojo para poder seguir.',
            icono: Icons.rule_rounded,
          ),
        ],
        if (state.campos.isNotEmpty) ...[
          const SizedBox(height: 22),
          const EtiquetaSeccion('Preguntas del médico'),
          for (final campo in state.campos) ...[
            CampoDinamico(
              key: ValueKey('${motivo.id}·${campo.clave}'),
              campo: campo,
              valor: state.respuestas[campo.clave],
              error: errores[campo.clave],
              habilitado: habilitado,
              alCambiar: (valor) =>
                  bloc.add(NuevaConsultaRespuestaCambiada(campo.clave, valor)),
            ),
            const SizedBox(height: 16),
          ],
        ] else
          const SizedBox(height: 22),
        const EtiquetaSeccion('Cuéntale qué pasa'),
        _Descripcion(
          inicial: state.descripcion,
          error: errores[claveDescripcion],
          habilitado: habilitado,
          alCambiar: (texto) =>
              bloc.add(NuevaConsultaDescripcionCambiada(texto)),
        ),
        const SizedBox(height: 20),
        const EtiquetaSeccion('Archivos'),
        Text(
          motivo.requiereAdjunto
              ? 'Este motivo necesita al menos un archivo: una foto o un PDF. '
                    'PDF, JPG o PNG de hasta 20 MB.'
              : 'Opcional: fotos, recetas o exámenes que ayuden al médico. '
                    'PDF, JPG o PNG de hasta 20 MB.',
          style: TextStyle(
            color: motivo.requiereAdjunto
                ? AppColors.alertaTexto
                : AppColors.textoSecundario,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        for (final adjunto in state.adjuntos) ...[
          FilaAdjunto(
            nombre: adjunto.nombre,
            tamano: adjunto.tamano,
            esImagen: adjunto.esImagen,
            nota: switch (adjunto) {
              AdjuntoPendiente() => 'Se sube al guardar o enviar',
              AdjuntoSubido() => 'Guardado',
            },
            quitando:
                adjunto is AdjuntoSubido &&
                state.quitandoId == adjunto.archivo.id,
            alQuitar: habilitado
                ? () => bloc.add(NuevaConsultaAdjuntoQuitado(adjunto))
                : null,
          ),
          const SizedBox(height: 8),
        ],
        if (errores[claveAdjuntos] != null) ...[
          RecuadroAviso.error(errores[claveAdjuntos]!),
          const SizedBox(height: 10),
        ],
        if (state.adjuntos.length < maximoAdjuntos)
          BotonSecundario(
            key: const Key('boton-adjuntar'),
            texto: state.adjuntos.isEmpty
                ? 'Adjuntar un archivo'
                : 'Adjuntar otro archivo',
            icono: Icons.attach_file_rounded,
            onPressed: habilitado ? () => _adjuntar(context) : null,
          ),
      ],
    );
  }
}

/// La descripción, con su propio controlador para no perder el cursor.
class _Descripcion extends StatefulWidget {
  final String inicial;
  final String? error;
  final bool habilitado;
  final ValueChanged<String> alCambiar;

  const _Descripcion({
    required this.inicial,
    required this.error,
    required this.habilitado,
    required this.alCambiar,
  });

  @override
  State<_Descripcion> createState() => _DescripcionState();
}

class _DescripcionState extends State<_Descripcion> {
  late final TextEditingController _texto = TextEditingController(
    text: widget.inicial,
  );

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('campo-descripcion'),
      controller: _texto,
      enabled: widget.habilitado,
      minLines: 5,
      maxLines: 12,
      maxLength: maximoDescripcion,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(color: AppColors.texto, fontSize: 15, height: 1.4),
      decoration: decoracionCliniq(
        pista:
            'Desde cuándo, qué sientes, qué has tomado y cualquier cosa que '
            'el médico deba saber.',
        contador: '',
      ).copyWith(errorText: widget.error),
      onChanged: widget.alCambiar,
    );
  }
}
