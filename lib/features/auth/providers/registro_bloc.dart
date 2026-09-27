import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../legal/data/legal_service.dart';
import '../data/auth_service.dart';
import '../data/models/datos_registro.dart';
import '../dominio/registro.dart';

// ── Eventos ──────────────────────────────────────────────────────────

sealed class RegistroEvent extends Equatable {
  const RegistroEvent();

  @override
  List<Object?> get props => [];
}

/// Al abrir el registro (y con «Reintentar»): los documentos legales
/// vigentes de la clínica.
class RegistroDocumentosPedidos extends RegistroEvent {
  const RegistroDocumentosPedidos();
}

/// Marcó o desmarcó la casilla de un documento.
class RegistroDocumentoMarcado extends RegistroEvent {
  final String clave;
  final bool aceptado;

  const RegistroDocumentoMarcado(this.clave, {required this.aceptado});

  @override
  List<Object?> get props => [clave, aceptado];
}

/// «Crear mi cuenta», con el formulario ya revisado.
class RegistroEnviado extends RegistroEvent {
  final DatosRegistro datos;

  const RegistroEnviado(this.datos);

  @override
  List<Object?> get props => [datos];
}

/// «Reenviar enlace», en «Revisa tu correo».
class RegistroReenvioPedido extends RegistroEvent {
  const RegistroReenvioPedido();
}

/// Pasó un segundo de la espera entre enlaces.
class RegistroSegundoCumplido extends RegistroEvent {
  const RegistroSegundoCumplido();
}

// ── Estado ───────────────────────────────────────────────────────────

/// La clave de la casilla única cuando la clínica no tiene vigente ninguno
/// de los documentos que se aceptan al registrarse: el API igual exige la
/// aceptación (`aceptaTerminos`), como la casilla sin enlaces del panel.
const String casillaSinDocumentos = '';

class RegistroState extends Equatable {
  final bool cargandoDocumentos;

  /// Los documentos cuya aceptación registra el API al crear la cuenta, con
  /// el título, la versión y el slug del servidor.
  final List<DocumentoLegal> documentos;

  /// Los demás documentos de los pacientes: se aceptan al entrar por
  /// primera vez. Se enseñan para leerlos, sin casilla.
  final List<DocumentoLegal> documentosAlEntrar;

  /// No se pudieron traer los documentos y no había copia.
  final String? errorDocumentos;

  /// Las claves de las casillas marcadas.
  final Set<String> aceptados;

  final bool enviando;

  /// Por qué el servidor no creó la cuenta, en sus palabras. Se enseña una
  /// vez, hasta el siguiente intento.
  final String? error;

  /// El correo al que se mandó el enlace; `null` mientras no hay cuenta.
  final String? correoRegistrado;

  final bool reenviando;

  /// Segundos que faltan para poder pedir otro enlace; 0, ya se puede.
  final int espera;

  final String? avisoReenvio;
  final String? errorReenvio;

  const RegistroState({
    this.cargandoDocumentos = true,
    this.documentos = const [],
    this.documentosAlEntrar = const [],
    this.errorDocumentos,
    this.aceptados = const {},
    this.enviando = false,
    this.error,
    this.correoRegistrado,
    this.reenviando = false,
    this.espera = 0,
    this.avisoReenvio,
    this.errorReenvio,
  });

  bool get registrado => correoRegistrado != null;

  /// Las casillas que hay que marcar: una por documento, o la única si la
  /// clínica no tiene ninguno vigente. Sin los documentos cargados, ninguna
  /// (y tampoco se puede enviar: no se acepta lo que no se pudo leer).
  List<String> get casillas {
    if (cargandoDocumentos || errorDocumentos != null) return const [];
    if (documentos.isEmpty) return const [casillaSinDocumentos];
    return [for (final d in documentos) d.clave];
  }

  /// Los documentos cargados y todas sus casillas marcadas.
  bool get todoAceptado {
    final requeridas = casillas;
    return requeridas.isNotEmpty && requeridas.every(aceptados.contains);
  }

  bool get puedeReenviar => registrado && !reenviando && espera <= 0;

  RegistroState copiarCon({
    bool? cargandoDocumentos,
    List<DocumentoLegal>? documentos,
    List<DocumentoLegal>? documentosAlEntrar,
    String? errorDocumentos,
    bool limpiarErrorDocumentos = false,
    Set<String>? aceptados,
    bool? enviando,
    String? error,
    bool limpiarError = false,
    String? correoRegistrado,
    bool? reenviando,
    int? espera,
    String? avisoReenvio,
    String? errorReenvio,
    bool limpiarReenvio = false,
  }) {
    return RegistroState(
      cargandoDocumentos: cargandoDocumentos ?? this.cargandoDocumentos,
      documentos: documentos ?? this.documentos,
      documentosAlEntrar: documentosAlEntrar ?? this.documentosAlEntrar,
      errorDocumentos: limpiarErrorDocumentos
          ? null
          : (errorDocumentos ?? this.errorDocumentos),
      aceptados: aceptados ?? this.aceptados,
      enviando: enviando ?? this.enviando,
      error: limpiarError ? null : (error ?? this.error),
      correoRegistrado: correoRegistrado ?? this.correoRegistrado,
      reenviando: reenviando ?? this.reenviando,
      espera: espera ?? this.espera,
      avisoReenvio: limpiarReenvio ? null : (avisoReenvio ?? this.avisoReenvio),
      errorReenvio: limpiarReenvio ? null : (errorReenvio ?? this.errorReenvio),
    );
  }

  @override
  List<Object?> get props => [
    cargandoDocumentos,
    documentos,
    documentosAlEntrar,
    errorDocumentos,
    aceptados,
    enviando,
    error,
    correoRegistrado,
    reenviando,
    espera,
    avisoReenvio,
    errorReenvio,
  ];
}

// ── Bloc ─────────────────────────────────────────────────────────────

/// Lo que se dice tras pedir otro enlace desde «Revisa tu correo»: la cuenta
/// se acaba de crear, así que se dice sin rodeos, como el panel.
const String avisoEnlaceReenviado =
    'Te enviamos un enlace nuevo. Revisa también la carpeta de correo no '
    'deseado.';

/// El autorregistro de un paciente: los documentos legales que se aceptan,
/// el envío (`POST /auth/registro`) y, con la cuenta creada, el reenvío del
/// enlace (`POST /auth/registro/reenviar`) con la espera de la clínica.
///
/// El formulario lo revisa la pantalla con las reglas de
/// `dominio/registro.dart`; aquí llega ya bueno.
class RegistroBloc extends Bloc<RegistroEvent, RegistroState> {
  final AuthService _servicio;
  final LegalService _legal;

  /// Los segundos entre un enlace y otro (`seguridad.reenvioSegundos`). Se
  /// leen cada vez: si la clínica los cambia, vale el valor nuevo.
  final int Function() _segundosEntreEnlaces;

  /// Un aviso por segundo mientras dura la espera. Se sustituye en las
  /// pruebas para contar los segundos a mano.
  final Stream<void> Function() _reloj;

  StreamSubscription<void>? _cuenta;

  RegistroBloc({
    required this._servicio,
    required this._legal,
    required this._segundosEntreEnlaces,
    Stream<void> Function()? reloj,
  }) : _reloj = reloj ?? _cadaSegundo,
       super(const RegistroState()) {
    on<RegistroDocumentosPedidos>(_alPedirDocumentos);
    on<RegistroDocumentoMarcado>(_alMarcar);
    on<RegistroEnviado>(_alEnviar);
    on<RegistroReenvioPedido>(_alReenviar);
    on<RegistroSegundoCumplido>(_alCumplirSegundo);
  }

  static Stream<void> _cadaSegundo() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  Future<void> _alPedirDocumentos(
    RegistroDocumentosPedidos event,
    Emitter<RegistroState> emit,
  ) async {
    emit(
      state.copiarCon(cargandoDocumentos: true, limpiarErrorDocumentos: true),
    );

    try {
      final reparto = repartirDocumentosDelPaciente(await _legal.documentos());

      emit(
        state.copiarCon(
          cargandoDocumentos: false,
          documentos: reparto.alRegistrarse,
          documentosAlEntrar: reparto.alEntrar,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          cargandoDocumentos: false,
          errorDocumentos: mensajeDeError(
            error,
            generico:
                'No pudimos cargar los documentos legales. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  void _alMarcar(RegistroDocumentoMarcado event, Emitter<RegistroState> emit) {
    final aceptados = {...state.aceptados};

    if (event.aceptado) {
      aceptados.add(event.clave);
    } else {
      aceptados.remove(event.clave);
    }

    emit(state.copiarCon(aceptados: aceptados));
  }

  Future<void> _alEnviar(
    RegistroEnviado event,
    Emitter<RegistroState> emit,
  ) async {
    if (state.enviando || state.registrado || !state.todoAceptado) return;

    emit(state.copiarCon(enviando: true, limpiarError: true));

    try {
      await _servicio.registrar(event.datos);

      emit(
        state.copiarCon(enviando: false, correoRegistrado: event.datos.correo),
      );
      _esperarParaReenviar(emit);
    } catch (error) {
      // 409 (correo o documento con cuenta), 400 (un dato que el API no
      // acepta) y 429 traen su motivo, y es el que se enseña.
      emit(
        state.copiarCon(
          enviando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos crear tu cuenta. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _alReenviar(
    RegistroReenvioPedido event,
    Emitter<RegistroState> emit,
  ) async {
    final correo = state.correoRegistrado;
    if (correo == null || !state.puedeReenviar) return;

    emit(state.copiarCon(reenviando: true, limpiarReenvio: true));

    try {
      await _servicio.reenviarConfirmacion(correo);

      emit(
        state.copiarCon(reenviando: false, avisoReenvio: avisoEnlaceReenviado),
      );
      _esperarParaReenviar(emit);
    } catch (error) {
      emit(
        state.copiarCon(
          reenviando: false,
          errorReenvio: mensajeDeError(
            error,
            generico: 'No pudimos pedir el enlace. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// Apaga «Reenviar enlace» los segundos de la clínica y los cuenta.
  void _esperarParaReenviar(Emitter<RegistroState> emit) {
    unawaited(_cuenta?.cancel());
    _cuenta = null;

    final segundos = _segundosEntreEnlaces();
    emit(state.copiarCon(espera: segundos > 0 ? segundos : 0));
    if (segundos <= 0) return;

    _cuenta = _reloj().listen((_) => add(const RegistroSegundoCumplido()));
  }

  void _alCumplirSegundo(
    RegistroSegundoCumplido event,
    Emitter<RegistroState> emit,
  ) {
    final quedan = state.espera - 1;

    if (quedan <= 0) {
      unawaited(_cuenta?.cancel());
      _cuenta = null;
    }

    emit(state.copiarCon(espera: quedan > 0 ? quedan : 0));
  }

  @override
  Future<void> close() async {
    await _cuenta?.cancel();
    return super.close();
  }
}
