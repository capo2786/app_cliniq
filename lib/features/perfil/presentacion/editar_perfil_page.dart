// lib/features/perfil/presentacion/editar_perfil_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import '../../auth/data/models/usuario.dart';
import '../../dependientes/dominio/validaciones.dart';
import '../providers/perfil_cubit.dart';
import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/en_contexto.dart';

/// Editar los datos propios que la API deja cambiar a uno mismo: nombre,
/// teléfono, datos demográficos, contacto de emergencia y perfil clínico.
///
/// El correo y la cédula no están: se cambian en la clínica.
class EditarPerfilPage extends StatefulWidget {
  final Usuario usuario;

  const EditarPerfilPage({super.key, required this.usuario});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final Usuario _u = widget.usuario;

  late final _nombre = TextEditingController(text: _u.nombre);
  late final _telefono = TextEditingController(text: _u.telefono ?? '');
  late final _direccion = TextEditingController(text: _u.direccion ?? '');
  late final _nacimiento = TextEditingController(
    text: deFechaIso(_u.fechaNacimiento) == null
        ? ''
        : FormatoFecha.corta(deFechaIso(_u.fechaNacimiento)!),
  );
  late final _alergias = TextEditingController(text: _u.alergias ?? '');
  late final _antecedentes = TextEditingController(
    text: _u.antecedentesPersonales ?? '',
  );
  late final _familiares = TextEditingController(
    text: _u.antecedentesFamiliares ?? '',
  );
  late final _habitos = TextEditingController(text: _u.habitos ?? '');
  late final _medicacion = TextEditingController(
    text: _u.medicacionHabitual ?? '',
  );
  late final _contactoNombre = TextEditingController(
    text: _u.contactoEmergencia?.nombre ?? '',
  );
  late final _contactoTelefono = TextEditingController(
    text: _u.contactoEmergencia?.telefono ?? '',
  );

  late String? _fechaNacimiento = _u.fechaNacimiento;
  late String _sexo = _u.sexo ?? '';
  late String _tipoSangre = _u.tipoSangre ?? '';
  late String? _contactoParentesco = _u.contactoEmergencia?.parentesco;

  bool _intentado = false;
  int? _secuenciaPrevia;
  bool _enviado = false;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _telefono,
      _direccion,
      _nacimiento,
      _alergias,
      _antecedentes,
      _familiares,
      _habitos,
      _medicacion,
      _contactoNombre,
      _contactoTelefono,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = Servicios.reloj.hoy();

    final elegida = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: deFechaIso(_fechaNacimiento) ?? DateTime(hoy.year - 30),
      firstDate: DateTime(1900),
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

  String? _errorContacto(String? _) {
    final nombre = _contactoNombre.text.trim();
    final telefono = _contactoTelefono.text.trim();

    if (nombre.isEmpty != telefono.isEmpty) {
      return 'El contacto de emergencia necesita nombre y teléfono.';
    }

    return errorDeTelefono(telefono);
  }

  void _guardar() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _intentado = true);

    if (_formKey.currentState?.validate() != true) return;

    final cubit = context.read<PerfilCubit>();
    _secuenciaPrevia = cubit.state.operacion?.secuencia;
    _enviado = true;

    // Los vacíos van como cadena vacía: para la API significan «borrar el
    // dato», que es lo que la persona hizo al vaciar el campo.
    cubit.guardarPerfil(_u.uid, {
      'nombre': _nombre.text.trim(),
      'telefono': _telefono.text.trim(),
      'direccion': _direccion.text.trim(),
      'fechaNacimiento': _fechaNacimiento ?? '',
      'sexo': _sexo,
      'tipoSangre': _tipoSangre,
      'alergias': _alergias.text.trim(),
      'antecedentesPersonales': _antecedentes.text.trim(),
      'antecedentesFamiliares': _familiares.text.trim(),
      'habitos': _habitos.text.trim(),
      'medicacionHabitual': _medicacion.text.trim(),
      'contactoEmergencia': {
        'nombre': _contactoNombre.text.trim(),
        'telefono': _contactoTelefono.text.trim(),
        'parentesco': _contactoParentesco ?? '',
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    // El parentesco del contacto de emergencia (`PARENTESCO`).
    final parentescos = catalogos.parentescos;
    final sexos = codigosParaElegir(catalogos.items(Catalogos.sexo), _sexo);
    final tiposSangre = codigosParaElegir(
      catalogos.items(Catalogos.tipoSangre),
      _tipoSangre,
    );

    return BlocConsumer<PerfilCubit, PerfilState>(
      listenWhen: (antes, ahora) =>
          _enviado && ahora.operacion?.secuencia != _secuenciaPrevia,
      listener: (context, state) {
        _enviado = false;
        final operacion = state.operacion;

        if (operacion?.exito == true) {
          mostrarAviso(context, operacion!.mensaje);
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final error =
            state.operacion != null &&
                state.operacion!.secuencia != _secuenciaPrevia &&
                !state.operacion!.exito &&
                _intentado
            ? state.operacion!.mensaje
            : null;

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Editar mis datos')),
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
                  if (error != null) ...[
                    Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.errorTexto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const EtiquetaSeccion('Datos personales'),
                  const EtiquetaCampo('Nombre completo'),
                  CampoCliniq(
                    controller: _nombre,
                    pista: 'Nombres y apellidos',
                    icono: Icons.badge_outlined,
                    mayusculas: TextCapitalization.words,
                    validator: errorDeNombre,
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Teléfono'),
                  CampoCliniq(
                    controller: _telefono,
                    pista: '0991234567',
                    icono: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                    validator: errorDeTelefono,
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Fecha de nacimiento'),
                  CampoCliniq(
                    controller: _nacimiento,
                    pista: 'dd/mm/aaaa',
                    icono: Icons.cake_outlined,
                    soloLectura: true,
                    onTap: _elegirFecha,
                    validator: (_) =>
                        _fechaNacimiento == null || _fechaNacimiento!.isEmpty
                        ? null
                        : errorDeFechaNacimiento(
                            _fechaNacimiento,
                            Servicios.reloj.hoy(),
                          ),
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
                              opciones: ['', ...sexos],
                              etiqueta: (s) => s.isEmpty
                                  ? 'Sin indicar'
                                  : etiquetaDe(catalogos, Catalogos.sexo, s),
                              pista: 'Sin indicar',
                              onChanged: (v) => setState(() => _sexo = v ?? ''),
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
                              opciones: ['', ...tiposSangre],
                              etiqueta: (t) => t.isEmpty
                                  ? 'Sin indicar'
                                  : etiquetaDe(
                                      catalogos,
                                      Catalogos.tipoSangre,
                                      t,
                                    ),
                              pista: 'Sin indicar',
                              onChanged: (v) =>
                                  setState(() => _tipoSangre = v ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Dirección'),
                  CampoCliniq(
                    controller: _direccion,
                    pista: 'Calle, número, sector',
                    icono: Icons.home_outlined,
                    maximo: 200,
                    mayusculas: TextCapitalization.sentences,
                    validator: (v) => errorDeLargo(v, 200),
                  ),
                  const SizedBox(height: 18),
                  const EtiquetaSeccion('Contacto de emergencia'),
                  CampoCliniq(
                    controller: _contactoNombre,
                    pista: 'Nombre',
                    icono: Icons.person_outline_rounded,
                    mayusculas: TextCapitalization.words,
                    validator: (v) => errorDeLargo(v, 100),
                  ),
                  const SizedBox(height: 10),
                  CampoCliniq(
                    controller: _contactoTelefono,
                    pista: 'Teléfono',
                    icono: Icons.phone_in_talk_outlined,
                    teclado: TextInputType.phone,
                    validator: _errorContacto,
                  ),
                  const SizedBox(height: 10),
                  SelectorCliniq<String>(
                    valor: _contactoParentesco,
                    opciones: [
                      ...parentescos,
                      if (_contactoParentesco != null &&
                          !parentescos.contains(_contactoParentesco))
                        _contactoParentesco!,
                    ],
                    etiqueta: (p) => p,
                    pista: 'Parentesco (opcional)',
                    icono: Icons.family_restroom_rounded,
                    onChanged: (v) => setState(() => _contactoParentesco = v),
                  ),
                  const SizedBox(height: 24),
                  const EtiquetaSeccion('Datos clínicos'),
                  for (final (etiqueta, controlador, pista, maximo) in [
                    (
                      'Alergias',
                      _alergias,
                      'Medicamentos, alimentos… o «ninguna»',
                      500,
                    ),
                    (
                      'Antecedentes personales',
                      _antecedentes,
                      'Enfermedades, cirugías',
                      2000,
                    ),
                    (
                      'Antecedentes familiares',
                      _familiares,
                      'Diabetes, hipertensión en la familia…',
                      2000,
                    ),
                    (
                      'Hábitos',
                      _habitos,
                      'Actividad física, tabaco, alcohol…',
                      2000,
                    ),
                    (
                      'Medicación habitual',
                      _medicacion,
                      'Qué tomas y cada cuánto',
                      2000,
                    ),
                  ]) ...[
                    EtiquetaCampo(etiqueta),
                    CampoCliniq(
                      controller: controlador,
                      pista: pista,
                      lineas: 2,
                      maximo: maximo,
                      mayusculas: TextCapitalization.sentences,
                      validator: (v) => errorDeLargo(v, maximo),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                  ConRed(
                    builder: (context, hayRed) => BotonPrincipal(
                      texto: 'Guardar cambios',
                      icono: Icons.save_outlined,
                      cargando: state.guardando,
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
