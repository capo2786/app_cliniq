// lib/features/dependientes/presentacion/formulario_dependiente_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../data/models/dependiente.dart';
import '../dominio/validaciones.dart';
import '../providers/dependientes_bloc.dart';

/// Registrar o editar un dependiente.
///
/// Devuelve el dependiente guardado al cerrar, para que quien abrió el
/// formulario —el paso «para quién» del agendamiento— lo pueda elegir.
class FormularioDependientePage extends StatefulWidget {
  final Dependiente? dependiente;

  const FormularioDependientePage({super.key, this.dependiente});

  @override
  State<FormularioDependientePage> createState() =>
      _FormularioDependientePageState();
}

class _FormularioDependientePageState extends State<FormularioDependientePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final Dependiente? _original = widget.dependiente;

  late final TextEditingController _nombre = TextEditingController(
    text: _original?.nombre ?? '',
  );
  late final TextEditingController _cedula = TextEditingController(
    text: _original?.cedula ?? '',
  );
  late final TextEditingController _nacimiento = TextEditingController(
    text: _textoFecha(_original?.fechaNacimiento),
  );
  late final TextEditingController _alergias = TextEditingController(
    text: _original?.alergias ?? '',
  );
  late final TextEditingController _antecedentes = TextEditingController(
    text: _original?.antecedentesPersonales ?? '',
  );
  late final TextEditingController _medicacion = TextEditingController(
    text: _original?.medicacionHabitual ?? '',
  );

  late String? _parentesco = _original?.parentesco;
  late String? _fechaNacimiento = _original?.fechaNacimiento;
  late String _tipoDocumento = _original?.tipoDocumento ?? 'CEDULA';
  late String _sexo = _original?.sexo ?? '';
  late String _tipoSangre = _original?.tipoSangre ?? '';

  bool _intentado = false;
  int? _secuenciaPrevia;
  bool _enviado = false;

  bool get _editando => _original != null;

  static String _textoFecha(String? iso) {
    final fecha = deFechaIso(iso);
    return fecha == null ? '' : FormatoFecha.corta(fecha);
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _cedula,
      _nacimiento,
      _alergias,
      _antecedentes,
      _medicacion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = Servicios.reloj.hoy();
    final actual = deFechaIso(_fechaNacimiento);

    final elegida = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: actual ?? DateTime(hoy.year - 10, hoy.month, hoy.day),
      firstDate: DateTime(1900),
      // No se puede nacer mañana: el selector ni siquiera lo ofrece.
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (elegida == null || !mounted) return;

    setState(() {
      _fechaNacimiento = fechaIso(elegida);
      _nacimiento.text = FormatoFecha.corta(elegida);
    });
  }

  void _guardar() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _intentado = true);

    if (_formKey.currentState?.validate() != true) return;

    final bloc = context.read<DependientesBloc>();

    _secuenciaPrevia = bloc.state.operacion?.secuencia;
    _enviado = true;

    bloc.add(
      DependienteGuardado(
        id: _original?.uid,
        datos: DatosDependiente(
          nombre: _nombre.text,
          parentesco: _parentesco ?? '',
          fechaNacimiento: _fechaNacimiento ?? '',
          tipoDocumento: _tipoDocumento,
          cedula: _cedula.text,
          sexo: _sexo.isEmpty ? null : _sexo,
          tipoSangre: _tipoSangre.isEmpty ? null : _tipoSangre,
          alergias: _alergias.text,
          antecedentesPersonales: _antecedentes.text,
          medicacionHabitual: _medicacion.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentescos = [
      ...context.watch<CatalogosCubit>().state.parentescos,
      // Un parentesco que ya no está en el catálogo se conserva al editar.
      if (_parentesco != null &&
          !context.read<CatalogosCubit>().state.parentescos.contains(
            _parentesco,
          ))
        _parentesco!,
    ];

    return BlocConsumer<DependientesBloc, DependientesState>(
      listenWhen: (antes, ahora) =>
          _enviado && ahora.operacion?.secuencia != _secuenciaPrevia,
      listener: (context, state) {
        final operacion = state.operacion;
        if (operacion == null) return;

        _enviado = false;
        mostrarAviso(context, operacion.mensaje, error: !operacion.exito);

        if (operacion.exito) Navigator.of(context).pop(operacion.guardado);
      },
      builder: (context, state) {
        final guardando = state.guardando;

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(
            title: Text(_editando ? 'Editar dependiente' : 'Nuevo dependiente'),
          ),
          body: FondoDegradado(
            child: Form(
              key: _formKey,
              autovalidateMode: _intentado
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: context.margenDeScroll(),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer: 'Para guardar necesitas conexión.',
                  ),
                  const EtiquetaSeccion('Identificación'),
                  const EtiquetaCampo('Nombre completo *'),
                  CampoCliniq(
                    controller: _nombre,
                    pista: 'Nombres y apellidos',
                    icono: Icons.badge_outlined,
                    mayusculas: TextCapitalization.words,
                    accion: TextInputAction.next,
                    validator: errorDeNombre,
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Parentesco *'),
                  SelectorCliniq<String>(
                    valor: _parentesco,
                    opciones: parentescos,
                    etiqueta: (p) => p,
                    pista: '¿Qué es para ti?',
                    icono: Icons.family_restroom_rounded,
                    onChanged: (valor) => setState(() => _parentesco = valor),
                    validator: (valor) =>
                        valor == null ? 'Elige el parentesco.' : null,
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Fecha de nacimiento *'),
                  CampoCliniq(
                    controller: _nacimiento,
                    pista: 'dd/mm/aaaa',
                    icono: Icons.cake_outlined,
                    soloLectura: true,
                    onTap: _elegirFecha,
                    validator: (_) => errorDeFechaNacimiento(
                      _fechaNacimiento,
                      Servicios.reloj.hoy(),
                    ),
                    sufijo: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Documento'),
                  SegmentedButton<String>(
                    segments: [
                      for (final e in nombresDeDocumento.entries)
                        ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {_tipoDocumento},
                    onSelectionChanged: (valor) {
                      setState(() => _tipoDocumento = valor.first);
                      _formKey.currentState?.validate();
                    },
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppColors.campo,
                      foregroundColor: AppColors.textoSuave,
                      selectedBackgroundColor: AppColors.acento,
                      selectedForegroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.bordeCampo),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CampoCliniq(
                    controller: _cedula,
                    pista: _tipoDocumento == 'CEDULA'
                        ? 'Cédula (10 dígitos, opcional)'
                        : 'Pasaporte (opcional)',
                    icono: Icons.credit_card_rounded,
                    teclado: _tipoDocumento == 'CEDULA'
                        ? TextInputType.number
                        : TextInputType.text,
                    formatos: _tipoDocumento == 'CEDULA'
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ]
                        : [LengthLimitingTextInputFormatter(20)],
                    validator: (valor) =>
                        errorDeDocumento(valor, _tipoDocumento),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const EtiquetaCampo('Sexo'),
                            SelectorCliniq<String>(
                              valor: _sexo,
                              opciones: ['', ...nombresDeSexo.keys],
                              etiqueta: (s) => s.isEmpty
                                  ? 'Sin indicar'
                                  : nombresDeSexo[s] ?? s,
                              pista: 'Sin indicar',
                              onChanged: (valor) =>
                                  setState(() => _sexo = valor ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const EtiquetaCampo('Tipo de sangre'),
                            SelectorCliniq<String>(
                              valor: _tipoSangre,
                              opciones: ['', ...tiposDeSangre],
                              etiqueta: (t) => t.isEmpty ? 'Sin indicar' : t,
                              pista: 'Sin indicar',
                              onChanged: (valor) =>
                                  setState(() => _tipoSangre = valor ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const EtiquetaSeccion('Datos clínicos'),
                  const EtiquetaCampo('Alergias'),
                  CampoCliniq(
                    controller: _alergias,
                    pista: 'Medicamentos, alimentos… o «ninguna»',
                    icono: Icons.warning_amber_rounded,
                    lineas: 2,
                    maximo: 500,
                    mayusculas: TextCapitalization.sentences,
                    validator: (v) => errorDeLargo(v, 500),
                  ),
                  const SizedBox(height: 8),
                  const EtiquetaCampo('Antecedentes personales'),
                  CampoCliniq(
                    controller: _antecedentes,
                    pista: 'Enfermedades, cirugías, condiciones',
                    icono: Icons.history_edu_rounded,
                    lineas: 3,
                    maximo: 1000,
                    mayusculas: TextCapitalization.sentences,
                    validator: (v) => errorDeLargo(v, 1000),
                  ),
                  const SizedBox(height: 8),
                  const EtiquetaCampo('Medicación habitual'),
                  CampoCliniq(
                    controller: _medicacion,
                    pista: 'Qué toma y cada cuánto',
                    icono: Icons.medication_outlined,
                    lineas: 3,
                    maximo: 1000,
                    mayusculas: TextCapitalization.sentences,
                    validator: (v) => errorDeLargo(v, 1000),
                  ),
                  const SizedBox(height: 22),
                  ConRed(
                    builder: (context, hayRed) => BotonPrincipal(
                      texto: _editando
                          ? 'Guardar cambios'
                          : 'Registrar dependiente',
                      icono: Icons.save_outlined,
                      cargando: guardando,
                      textoCargando: 'Guardando…',
                      onPressed: hayRed ? _guardar : null,
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
