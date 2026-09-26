import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/catalogos/catalogos_cubit.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/cita.dart';
import '../../providers/citas_bloc.dart';
import '../../providers/citas_event.dart';
import '../../providers/citas_state.dart';

/// Abre la hoja para cancelar una cita. Devuelve `true` si se canceló.
Future<bool?> mostrarCancelarCita(BuildContext context, Cita cita) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<CitasBloc>()),
        BlocProvider.value(value: context.read<CatalogosCubit>()),
      ],
      child: _CancelarCita(cita: cita),
    ),
  );
}

/// Cancelar con un motivo del catálogo y, si se quiere, un detalle.
///
/// El motivo es obligatorio porque el médico lo recibe en su aviso: «el
/// paciente no puede asistir» y «se reprogramó para otra fecha» le piden
/// cosas distintas.
class _CancelarCita extends StatefulWidget {
  final Cita cita;

  const _CancelarCita({required this.cita});

  @override
  State<_CancelarCita> createState() => _CancelarCitaState();
}

class _CancelarCitaState extends State<_CancelarCita> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _detalle = TextEditingController();

  String? _motivo;

  /// La secuencia de la última acción antes de enviar: la respuesta a esta
  /// cancelación es la primera con una secuencia distinta.
  int? _secuenciaPrevia;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_formKey.currentState?.validate() != true) return;

    final bloc = context.read<CitasBloc>();

    setState(() {
      _secuenciaPrevia = bloc.state.accion?.secuencia;
      _enviado = true;
      _error = null;
    });

    bloc.add(
      CitaCancelacionSolicitada(
        cita: widget.cita,
        motivo: _motivo!,
        detalle: _detalle.text.trim().isEmpty ? null : _detalle.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motivos = context.watch<CatalogosCubit>().state.motivosCancelacion;

    return BlocConsumer<CitasBloc, CitasState>(
      listenWhen: (antes, ahora) =>
          _enviado && ahora.accion?.secuencia != _secuenciaPrevia,
      listener: (context, state) {
        final accion = state.accion;
        if (accion == null) return;

        _enviado = false;

        if (accion.exito) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _error = accion.mensaje);
        }
      },
      builder: (context, state) {
        final enviando = state.cancelandoId == widget.cita.id;

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
                        Icons.event_busy_rounded,
                        color: AppColors.peligroSuave,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '¿Cancelar la cita?',
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
                  Text(
                    '${FormatoFecha.diaLargo(widget.cita.inicio)}, '
                    '${FormatoFecha.hora(widget.cita.inicio)} con '
                    '${widget.cita.medicoVisible}. Le avisaremos al médico.',
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    RecuadroAviso.error(_error!),
                  ],
                  const SizedBox(height: 18),
                  const EtiquetaCampo('Motivo'),
                  SelectorCliniq<String>(
                    valor: _motivo,
                    opciones: motivos,
                    etiqueta: (m) => m,
                    pista: 'Elige un motivo',
                    icono: Icons.help_outline_rounded,
                    onChanged: enviando
                        ? null
                        : (valor) => setState(() => _motivo = valor),
                    validator: (valor) => valor == null
                        ? 'Elige el motivo de la cancelación.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const EtiquetaCampo('Detalle (opcional)'),
                  CampoCliniq(
                    controller: _detalle,
                    pista: 'Algo que el médico deba saber',
                    lineas: 3,
                    maximo: 1000,
                    habilitado: !enviando,
                    mayusculas: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 18),
                  BotonPrincipal(
                    texto: 'Cancelar cita',
                    icono: Icons.event_busy_rounded,
                    cargando: enviando,
                    textoCargando: 'Cancelando…',
                    onPressed: _enviar,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: enviando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Mantener la cita',
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
