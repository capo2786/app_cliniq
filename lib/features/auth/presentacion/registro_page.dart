// lib/features/auth/presentacion/registro_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../dependientes/dominio/validaciones.dart';
import '../../legal/data/legal_service.dart';
import '../data/auth_service.dart';
import '../data/models/datos_registro.dart';
import '../dominio/registro.dart';
import '../providers/registro_bloc.dart';
import 'widgets/documentos_del_registro.dart';
import 'widgets/fortaleza_contrasena.dart';
import 'widgets/revisa_tu_correo.dart';

/// Crear una cuenta de paciente, dentro de la aplicación.
///
/// Es el registro del panel web (`/registro`) con el diseño de la
/// aplicación: los mismos campos, reglas y mensajes, los documentos legales
/// de la clínica para leer y aceptar, y el mismo `POST /auth/registro`. La
/// cuenta queda pendiente hasta confirmar el correo: después del envío se ve
/// «Revisa tu correo». Al cerrar devuelve el correo registrado, para dejarlo
/// escrito en el acceso.
class RegistroPage extends StatelessWidget {
  final AuthService? servicio;
  final LegalService? legal;

  const RegistroPage({super.key, this.servicio, this.legal});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegistroBloc(
        servicio: servicio ?? Servicios.auth,
        legal: legal ?? Servicios.legal,
        segundosEntreEnlaces: () =>
            context.read<ConfigPublicaCubit>().config.seguridad.reenvioSegundos,
      )..add(const RegistroDocumentosPedidos()),
      child: BlocConsumer<RegistroBloc, RegistroState>(
        listenWhen: (antes, ahora) => !antes.registrado && ahora.registrado,
        // El gestor de contraseñas del teléfono ofrece guardar la nueva.
        listener: (_, _) => TextInput.finishAutofillContext(),
        buildWhen: (antes, ahora) => antes.registrado != ahora.registrado,
        builder: (context, state) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: state.registrado
              ? const RevisaTuCorreo(key: ValueKey('revisa-tu-correo'))
              : const _FormularioDeRegistro(key: ValueKey('formulario')),
        ),
      ),
    );
  }
}

/// Los campos, en el orden en que se revisan: el primero con error es al
/// que se lleva la pantalla al tocar «Crear mi cuenta».
enum _Campo {
  nombre,
  correo,
  telefono,
  documento,
  nacimiento,
  contrasena,
  confirmar,
  documentos,
}

class _FormularioDeRegistro extends StatefulWidget {
  const _FormularioDeRegistro({super.key});

  @override
  State<_FormularioDeRegistro> createState() => _FormularioDeRegistroState();
}

class _FormularioDeRegistroState extends State<_FormularioDeRegistro> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _telefono = TextEditingController();
  final TextEditingController _documento = TextEditingController();
  final TextEditingController _nacimiento = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  final FocusNode _focoCorreo = FocusNode();
  final FocusNode _focoTelefono = FocusNode();
  final FocusNode _focoDocumento = FocusNode();
  final FocusNode _focoContrasena = FocusNode();
  final FocusNode _focoConfirmar = FocusNode();

  /// Dónde está cada campo, para llevar la pantalla al primero con error.
  final Map<_Campo, GlobalKey> _anclas = {
    for (final campo in _Campo.values) campo: GlobalKey(),
  };

  String _tipoDocumento = 'CEDULA';
  String _sexo = '';
  String? _fechaNacimiento;
  bool _verContrasena = false;
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    // La barra de fortaleza sigue a la contraseña letra por letra.
    _contrasena.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _correo,
      _telefono,
      _documento,
      _nacimiento,
      _contrasena,
      _confirmar,
    ]) {
      c.dispose();
    }
    for (final f in [
      _focoCorreo,
      _focoTelefono,
      _focoDocumento,
      _focoContrasena,
      _focoConfirmar,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  int get _minimo =>
      context.read<ConfigPublicaCubit>().config.seguridad.passwordMinimo;

  bool get _validarCedula =>
      context.read<ConfigPublicaCubit>().config.general.validarCedula;

  /// El error de cada campo, con las mismas reglas que pintan los campos.
  String? _errorDe(_Campo campo) => switch (campo) {
    _Campo.nombre => errorDeNombreRegistro(_nombre.text),
    _Campo.correo => errorDeCorreoRegistro(_correo.text),
    _Campo.telefono => errorDeTelefono(_telefono.text),
    _Campo.documento => errorDeDocumentoRegistro(
      _documento.text,
      _tipoDocumento,
      validarCedula: _validarCedula,
    ),
    _Campo.nacimiento => errorDeFechaRegistro(
      _fechaNacimiento,
      Servicios.reloj.hoy(),
    ),
    _Campo.contrasena => errorDeContrasenaRegistro(
      _contrasena.text,
      minimo: _minimo,
    ),
    _Campo.confirmar => errorDeConfirmacion(_confirmar.text, _contrasena.text),
    _Campo.documentos =>
      context.read<RegistroBloc>().state.todoAceptado
          ? null
          : mensajeFaltaAceptar,
  };

  Future<void> _elegirFecha() async {
    cerrarTeclado();
    final hoy = Servicios.reloj.hoy();

    final elegida = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate:
          deFechaIso(_fechaNacimiento) ?? DateTime(hoy.year - 30, 1, 1),
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

  /// Del número del documento se sigue a la fecha si falta, y si no a la
  /// contraseña.
  void _despuesDelDocumento() {
    if (_fechaNacimiento == null) {
      unawaited(_elegirFecha());
    } else {
      _focoContrasena.requestFocus();
    }
  }

  void _enviar() {
    cerrarTeclado();
    setState(() => _intentado = true);
    _formKey.currentState?.validate();

    final conError = _Campo.values.where((c) => _errorDe(c) != null);
    if (conError.isNotEmpty) {
      final ancla = _anclas[conError.first]?.currentContext;
      if (ancla != null) {
        Scrollable.ensureVisible(
          ancla,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
      return;
    }

    context.read<RegistroBloc>().add(
      RegistroEnviado(
        DatosRegistro(
          nombre: _nombre.text,
          email: _correo.text,
          telefono: _telefono.text,
          tipoDocumento: _tipoDocumento,
          cedula: _documento.text,
          fechaNacimiento: _fechaNacimiento!,
          sexo: _sexo,
          password: _contrasena.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistroBloc>().state;
    final clinica = context.config.clinica;
    final enviando = state.enviando;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Registro de paciente')),
      bottomNavigationBar: BarraDeAccion(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error case final error?) ...[
              RecuadroAviso.error(error, key: const Key('error-registro')),
              const SizedBox(height: 10),
            ],
            ConRed(
              builder: (context, hayRed) => BotonPrincipal(
                key: const Key('boton-crear-mi-cuenta'),
                texto: 'Crear mi cuenta',
                icono: Icons.person_add_alt_1_rounded,
                cargando: enviando,
                textoCargando: 'Creando tu cuenta…',
                onPressed: hayRed ? _enviar : null,
              ),
            ),
          ],
        ),
      ),
      body: FondoDegradado(
        child: Form(
          key: _formKey,
          autovalidateMode: _intentado
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: AutofillGroup(
            // Todo el formulario construido a la vez (no una lista perezosa):
            // así se revisan todos los campos y se puede llevar la pantalla
            // a cualquiera de ellos.
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: context.margenDeScroll(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer: 'Para crear tu cuenta necesitas conexión.',
                  ),
                  TarjetaEncabezado(
                    icono: Icons.person_add_alt_1_rounded,
                    titulo: 'Crea tu cuenta',
                    descripcion:
                        'Te pedimos lo justo para identificarte en '
                        '${clinica.nombre}. Después te enviaremos un enlace '
                        'para confirmar tu correo.',
                  ),
                  _YaTengoCuenta(alIngresar: () => Navigator.of(context).pop()),
                  const SizedBox(height: 8),
                  const EtiquetaSeccion('Tus datos'),
                  ..._datosPersonales(enviando),
                  const SizedBox(height: 22),
                  const EtiquetaSeccion('Identificación'),
                  ..._identificacion(enviando),
                  const SizedBox(height: 22),
                  const EtiquetaSeccion('Contraseña'),
                  ..._contrasenas(enviando),
                  const SizedBox(height: 22),
                  EtiquetaSeccion(
                    'Documentos legales',
                    key: _anclas[_Campo.documentos],
                  ),
                  DocumentosDelRegistro(intentado: _intentado),
                  const SizedBox(height: 22),
                  const Text(
                    '¿Eres médico o parte del personal? Tu cuenta la crea la '
                    'clínica.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoTenue,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _datosPersonales(bool enviando) => [
    EtiquetaCampo('Nombres y apellidos *', key: _anclas[_Campo.nombre]),
    CampoCliniq(
      key: const Key('registro-nombre'),
      controller: _nombre,
      pista: 'Ana María Torres Pérez',
      icono: Icons.badge_outlined,
      habilitado: !enviando,
      mayusculas: TextCapitalization.words,
      accion: TextInputAction.next,
      autofill: const [AutofillHints.name],
      validator: errorDeNombreRegistro,
      onSubmitted: (_) => _focoCorreo.requestFocus(),
    ),
    const SizedBox(height: 14),
    EtiquetaCampo('Correo electrónico *', key: _anclas[_Campo.correo]),
    CampoCliniq(
      key: const Key('registro-correo'),
      controller: _correo,
      foco: _focoCorreo,
      pista: 'nombre@correo.com',
      icono: Icons.alternate_email_rounded,
      habilitado: !enviando,
      teclado: TextInputType.emailAddress,
      accion: TextInputAction.next,
      autofill: const [AutofillHints.email],
      validator: errorDeCorreoRegistro,
      onSubmitted: (_) => _focoTelefono.requestFocus(),
    ),
    const SizedBox(height: 14),
    EtiquetaCampo('Teléfono', key: _anclas[_Campo.telefono]),
    CampoCliniq(
      key: const Key('registro-telefono'),
      controller: _telefono,
      foco: _focoTelefono,
      pista: '0991234567',
      icono: Icons.phone_outlined,
      habilitado: !enviando,
      teclado: TextInputType.phone,
      accion: TextInputAction.next,
      autofill: const [AutofillHints.telephoneNumber],
      formatos: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
        LengthLimitingTextInputFormatter(16),
      ],
      validator: errorDeTelefono,
      onSubmitted: (_) => _focoDocumento.requestFocus(),
    ),
  ];

  List<Widget> _identificacion(bool enviando) {
    final catalogos = context.catalogos;
    final esCedula = _tipoDocumento == 'CEDULA';
    final tipos = codigosParaElegir(
      catalogos.items(Catalogos.tipoDocumento),
      _tipoDocumento,
    );
    final sexos = codigosParaElegir(catalogos.items(Catalogos.sexo), _sexo);
    final nombreDocumento = etiquetaDe(
      catalogos,
      Catalogos.tipoDocumento,
      _tipoDocumento,
    ).toLowerCase();

    return [
      const EtiquetaCampo('Documento *'),
      _TipoDeDocumento(
        tipos: tipos,
        elegido: _tipoDocumento,
        etiqueta: (codigo) =>
            etiquetaDe(catalogos, Catalogos.tipoDocumento, codigo),
        alElegir: enviando
            ? null
            : (codigo) {
                setState(() => _tipoDocumento = codigo);
                // Como el panel: el número se queda y se vuelve a revisar.
                if (_intentado) _formKey.currentState?.validate();
              },
      ),
      const SizedBox(height: 14),
      EtiquetaCampo(
        'Número de $nombreDocumento *',
        key: _anclas[_Campo.documento],
      ),
      CampoCliniq(
        key: const Key('registro-documento'),
        controller: _documento,
        foco: _focoDocumento,
        pista: esCedula ? '1712345678' : 'A1234567',
        icono: Icons.credit_card_rounded,
        habilitado: !enviando,
        teclado: esCedula ? TextInputType.number : TextInputType.text,
        mayusculas: esCedula
            ? TextCapitalization.none
            : TextCapitalization.characters,
        accion: TextInputAction.next,
        formatos: esCedula
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]
            : [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(20),
              ],
        validator: (valor) => errorDeDocumentoRegistro(
          valor,
          _tipoDocumento,
          validarCedula: _validarCedula,
        ),
        onSubmitted: (_) => _despuesDelDocumento(),
      ),
      const SizedBox(height: 14),
      EtiquetaCampo('Fecha de nacimiento *', key: _anclas[_Campo.nacimiento]),
      CampoCliniq(
        key: const Key('registro-nacimiento'),
        controller: _nacimiento,
        pista: 'dd/mm/aaaa',
        icono: Icons.cake_outlined,
        habilitado: !enviando,
        soloLectura: true,
        onTap: _elegirFecha,
        validator: (_) =>
            errorDeFechaRegistro(_fechaNacimiento, Servicios.reloj.hoy()),
        sufijo: const Icon(
          Icons.calendar_month_rounded,
          color: AppColors.textoSecundario,
        ),
      ),
      const SizedBox(height: 14),
      const EtiquetaCampo('Sexo'),
      SelectorCliniq<String>(
        key: const Key('registro-sexo'),
        valor: _sexo,
        opciones: ['', ...sexos],
        etiqueta: (s) => s.isEmpty
            ? 'Prefiero no decirlo'
            : etiquetaDe(catalogos, Catalogos.sexo, s),
        pista: 'Prefiero no decirlo',
        icono: Icons.wc_rounded,
        onChanged: enviando
            ? null
            : (valor) => setState(() => _sexo = valor ?? ''),
      ),
    ];
  }

  List<Widget> _contrasenas(bool enviando) {
    final minimo = context.config.seguridad.passwordMinimo;

    return [
      EtiquetaCampo('Contraseña *', key: _anclas[_Campo.contrasena]),
      CampoCliniq(
        key: const Key('registro-contrasena'),
        controller: _contrasena,
        foco: _focoContrasena,
        pista: 'Mínimo $minimo caracteres',
        icono: Icons.lock_outline_rounded,
        oculto: !_verContrasena,
        habilitado: !enviando,
        accion: TextInputAction.next,
        autofill: const [AutofillHints.newPassword],
        validator: (valor) => errorDeContrasenaRegistro(valor, minimo: minimo),
        onSubmitted: (_) => _focoConfirmar.requestFocus(),
        sufijo: IconButton(
          tooltip: _verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
          icon: Icon(
            _verContrasena
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textoSecundario,
            size: 21,
          ),
          onPressed: () => setState(() => _verContrasena = !_verContrasena),
        ),
      ),
      FortalezaDeContrasena(contrasena: _contrasena.text, minimo: minimo),
      const SizedBox(height: 14),
      EtiquetaCampo('Repite la contraseña *', key: _anclas[_Campo.confirmar]),
      CampoCliniq(
        key: const Key('registro-confirmar'),
        controller: _confirmar,
        foco: _focoConfirmar,
        pista: 'Escríbela de nuevo',
        icono: Icons.lock_reset_rounded,
        oculto: !_verContrasena,
        habilitado: !enviando,
        accion: TextInputAction.done,
        autofill: const [AutofillHints.newPassword],
        validator: (valor) => errorDeConfirmacion(valor, _contrasena.text),
        onSubmitted: (_) {
          if (!enviando) _enviar();
        },
      ),
    ];
  }
}

/// «¿Ya tienes una cuenta? Ingresa aquí»: vuelve al acceso.
class _YaTengoCuenta extends StatelessWidget {
  final VoidCallback alIngresar;

  const _YaTengoCuenta({required this.alIngresar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '¿Ya tienes una cuenta?',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          key: const Key('boton-ya-tengo-cuenta'),
          onPressed: alIngresar,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.acentoSuave,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
          child: const Text(
            'Ingresa aquí',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Cédula o pasaporte (o lo que traiga `TIPO_DOCUMENTO`), con las etiquetas
/// de la clínica.
class _TipoDeDocumento extends StatelessWidget {
  final List<String> tipos;
  final String elegido;
  final String Function(String codigo) etiqueta;
  final ValueChanged<String>? alElegir;

  const _TipoDeDocumento({
    required this.tipos,
    required this.elegido,
    required this.etiqueta,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    final alElegir = this.alElegir;

    return SegmentedButton<String>(
      key: const Key('registro-tipo-documento'),
      segments: [
        for (final codigo in tipos)
          ButtonSegment(value: codigo, label: Text(etiqueta(codigo))),
      ],
      selected: {elegido},
      onSelectionChanged: alElegir == null
          ? null
          : (valor) => alElegir(valor.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.campo,
        foregroundColor: AppColors.textoSuave,
        selectedBackgroundColor: AppColors.acento,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.bordeCampo),
      ),
    );
  }
}
