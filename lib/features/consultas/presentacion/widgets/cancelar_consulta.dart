import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/consulta.dart';
import '../../providers/detalle_consulta_bloc.dart';
import '../../providers/detalle_consulta_event.dart';
import '../../providers/detalle_consulta_state.dart';

/// Abre la hoja para cancelar una consulta enviada. `true` si se canceló.
Future<bool?> mostrarCancelarConsulta(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<DetalleConsultaBloc>(),
      child: const _CancelarConsulta(),
    ),
  );
}

/// Cancelar con un motivo: el médico lo recibe en su aviso.
///
/// Solo se puede mientras la consulta está ENVIADA, es decir, antes de que
/// el médico la abra.
class _CancelarConsulta extends StatefulWidget {
  const _CancelarConsulta();

  @override
  State<_CancelarConsulta> createState() => _CancelarConsultaState();
}

class _CancelarConsultaState extends State<_CancelarConsulta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _motivo = TextEditingController();

  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _cancelar() {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _enviado = true;
      _error = null;
    });
    context.read<DetalleConsultaBloc>().add(
      DetalleConsultaCancelada(_motivo.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DetalleConsultaBloc, DetalleConsultaState>(
      listenWhen: (antes, ahora) =>
          _enviado && antes.cancelando && !ahora.cancelando,
      listener: (context, state) {
        _enviado = false;

        if (state.detalle?.estado == EstadoConsulta.cancelada) {
          Navigator.of(context).pop(true);
        } else {
          setState(
            () => _error =
                state.aviso?.mensaje ?? 'No se pudo cancelar la consulta.',
          );
        }
      },
      builder: (context, state) {
        final error = _error;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            18,
            22,
            22 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: AppColors.peligroSuave,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '¿Cancelar la consulta?',
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El médico todavía no la abre. Le avisaremos que ya no '
                    'necesitas su respuesta.',
                    style: TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    RecuadroAviso.error(error),
                  ],
                  const SizedBox(height: 18),
                  const EtiquetaCampo('Motivo'),
                  CampoCliniq(
                    key: const Key('campo-motivo-cancelacion'),
                    controller: _motivo,
                    pista: 'Ej.: Ya me siento mejor',
                    lineas: 3,
                    maximo: 500,
                    habilitado: !state.cancelando,
                    mayusculas: TextCapitalization.sentences,
                    validator: (valor) => (valor ?? '').trim().isEmpty
                        ? 'Cuéntanos por qué la cancelas.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  BotonPrincipal(
                    texto: 'Cancelar consulta',
                    icono: Icons.cancel_outlined,
                    cargando: state.cancelando,
                    textoCargando: 'Cancelando…',
                    onPressed: _cancelar,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: state.cancelando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Mantener la consulta',
                        style: TextStyle(color: AppColors.textoSecundario),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
