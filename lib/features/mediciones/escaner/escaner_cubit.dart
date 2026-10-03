// lib/features/mediciones/escaner/escaner_cubit.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import 'analizador_de_medicion.dart';
import 'aviso_experimental.dart';
import 'control_de_medicion.dart';
import 'estimador_en_vivo.dart';
import 'fuente_de_cuadros.dart';
import 'mediciones_del_resultado.dart';
import 'motor_signos_camara.dart';
import 'escaner_state.dart';
import 'rostro/rostro_detectado.dart';
import 'serie_senal.dart';

export 'escaner_state.dart';

/// El escáner experimental, paso a paso.
///
/// Los cuadros que llegan de la [FuenteDeCuadros] ya son números; el
/// [ControlDeMedicion] decide cuáles entran en la serie y lleva la cuenta
/// con el tiempo de los propios cuadros (no con un reloj aparte): si la
/// cámara se atasca, la cuenta se para y, a los [plazoSinCuadros], se avisa.
/// Todo se suelta al terminar, al cancelar o al descartar.
///
/// En el modo rostro la cuenta arranca sola con la cara bien encuadrada, se
/// pausa si se pierde y se detiene si no vuelve; la guía de encuadre dice
/// qué hacer. La última detección del rostro va en [rostroEnVivo], aparte
/// del estado, para pintar la malla sin reconstruir toda la pantalla.
///
/// Mientras mide, cada segundo el [EstimadorEnVivo] da la calidad, el
/// consejo, la onda y la FC en vivo. Si la calidad se queda por debajo de
/// [calidadParaSeguir] durante [segundosDeCalidadBaja], se detiene con un
/// consejo y «Reintentar».
class EscanerCubit extends Cubit<EscanerState> {
  final FuenteDeCuadros _fuente;
  final AnalizadorDeMedicion _analizador;
  final ColaMediciones _cola;
  final AvisoDelEscaner _aviso;
  final String _uid;
  final String? _pacienteId;
  final DateTime Function() _ahora;

  /// Sin cuadros durante este tiempo, la medición se da por perdida.
  static const Duration plazoSinCuadros = Duration(seconds: 5);

  static const double calidadParaSeguir = 0.3;
  static const double segundosDeCalidadBaja = 8;

  ControlDeMedicion? _control;
  final EstimadorEnVivo _estimador;
  StreamSubscription<CuadroPpg>? _suscripcion;
  Timer? _vigilancia;
  DateTime _ultimoCuadro = DateTime.now();
  double? _bajaDesde;
  bool _terminando = false;

  /// La última detección del rostro (o `null`): para la malla.
  final ValueNotifier<RostroDetectado?> rostroEnVivo = ValueNotifier(null);

  EscanerCubit({
    required this._fuente,
    required MotorSignosCamara motor,
    required this._analizador,
    required this._cola,
    required this._aviso,
    required this._uid,
    required int segundos,
    this._pacienteId,
    bool dedoActivo = false,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now,
       _estimador = EstimadorEnVivo(motor: motor),
       super(
         EscanerState(
           segundos: segundos,
           segundosRestantes: segundos,
           dedoActivo: dedoActivo,
         ),
       );

  /// La fuente, para pintar su vista previa.
  FuenteDeCuadros get fuente => _fuente;

  /// Después del aviso: elegir el modo, o directo al rostro si la clínica
  /// no ofrece el dedo.
  EscanerState get _inicio => state.dedoActivo
      ? state.copiarCon(paso: PasoEscaner.modo)
      : state.copiarCon(
          paso: PasoEscaner.instrucciones,
          modo: ModoEscaner.rostro,
        );

  /// Al abrir: el aviso la primera vez; después, el inicio.
  Future<void> iniciar() async {
    final aceptado = await _aviso.aceptado(_uid);
    if (isClosed) return;
    emit(aceptado ? _inicio : state.copiarCon(paso: PasoEscaner.aviso));
  }

  Future<void> aceptarAviso() async {
    await _aviso.aceptar(_uid);
    if (!isClosed) emit(_inicio);
  }

  void elegirModo(ModoEscaner modo) =>
      emit(state.copiarCon(paso: PasoEscaner.instrucciones, modo: modo));

  /// Lo de una medición en vivo, en blanco.
  EscanerState _enBlanco(EscanerState s) => s.copiarCon(
    segundosRestantes: s.segundos,
    fase: FaseMedicion.preparando,
    limpiarInstruccion: true,
    porColorDePiel: false,
    lectura: const LecturaEnVivo(),
    historialFc: const [],
    latidos: 0,
  );

  /// Vuelve al inicio (elegir el modo, o las instrucciones del rostro),
  /// soltando lo que hubiera.
  Future<void> volverAModos() async {
    await _soltar();
    if (isClosed) return;
    emit(
      _enBlanco(_inicio).copiarCon(
        limpiarResultado: true,
        limpiarFallo: true,
        limpiarContexto: true,
        limpiarRegistro: true,
        limpiarError: true,
      ),
    );
  }

  /// Abre la cámara y empieza a medir.
  Future<void> empezar() async {
    await _soltar();
    if (isClosed) return;
    emit(
      _enBlanco(state).copiarCon(
        paso: PasoEscaner.abriendo,
        limpiarResultado: true,
        limpiarFallo: true,
        limpiarRegistro: true,
        limpiarError: true,
      ),
    );

    _terminando = false;
    _control = ControlDeMedicion(
      segundos: state.segundos,
      conEncuadre: state.modo == ModoEscaner.rostro,
    );
    try {
      _suscripcion = _fuente.cuadros.listen(_alCuadro);
      await _fuente.abrir(state.modo);
    } catch (error) {
      await _soltar();
      if (isClosed) return;
      final camara = error is ErrorDeCamara
          ? error
          : const ErrorDeCamara(MotivoErrorCamara.otro);
      emit(
        state.copiarCon(
          paso: PasoEscaner.fallo,
          fallo: camara.mensaje,
          fallaPorPermiso: camara.motivo == MotivoErrorCamara.permisoBloqueado,
        ),
      );
      return;
    }
    if (isClosed || state.paso != PasoEscaner.abriendo) return;

    _ultimoCuadro = DateTime.now();
    _vigilancia = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().difference(_ultimoCuadro) > plazoSinCuadros) {
        unawaited(
          _detener(
            'La cámara dejó de enviar imágenes. Vuelve a intentarlo; si '
            'sigue pasando, cierra otras aplicaciones que usen la cámara.',
          ),
        );
      }
    });
    emit(state.copiarCon(paso: PasoEscaner.midiendo));
  }

  void _alCuadro(CuadroPpg cuadro) {
    // Los que llegan mientras la cámara arranca no cuentan.
    final control = _control;
    if (isClosed ||
        _terminando ||
        control == null ||
        state.paso != PasoEscaner.midiendo) {
      return;
    }

    _ultimoCuadro = DateTime.now();
    if (!identical(rostroEnVivo.value, cuadro.rostro)) {
      rostroEnVivo.value = cuadro.rostro;
    }

    final evento = control.alCuadro(cuadro);
    if (evento == EventoDeMedicion.perdida) {
      unawaited(
        _detener(
          'Perdimos tu cara durante varios segundos. Sostén el teléfono '
          'frente a ti, con tu cara dentro del marco, y vuelve a intentarlo.',
        ),
      );
      return;
    }
    if (evento == EventoDeMedicion.pausa) _bajaDesde = null;

    var nuevo = state.copiarCon(
      fase: control.fase,
      instruccion: control.instruccion,
      porColorDePiel: cuadro.porColorDePiel,
      segundosRestantes: control.restantes,
    );
    if (control.fase == FaseMedicion.midiendo) {
      final lectura = _estimador.avanzar(
        SerieSenal.de(state.modo, control.cuadros),
        control.medido,
      );
      if (lectura != null) {
        _vigilarCalidad(lectura, control.medido);
        if (isClosed || _terminando) return;
        nuevo = nuevo.copiarCon(
          lectura: lectura,
          historialFc: _estimador.historial,
          latidos: _estimador.latidos,
        );
      }
    }
    if (nuevo != state) emit(nuevo);

    if (evento == EventoDeMedicion.completa) unawaited(_terminar());
  }

  void _vigilarCalidad(LecturaEnVivo lectura, double transcurrido) {
    final calidad = lectura.calidad;
    if (calidad == null || calidad >= calidadParaSeguir) {
      _bajaDesde = null;
      return;
    }
    _bajaDesde ??= transcurrido;
    if (transcurrido - _bajaDesde! >= segundosDeCalidadBaja) {
      final consejo = lectura.consejo;
      unawaited(
        _detener(
          consejo == null
              ? ConsejosEscaner.paraElMotivo(null, state.modo)
              : 'La señal no fue buena: ${consejo.toLowerCase()}. '
                    '${ConsejosEscaner.paraElMotivo(null, state.modo)}',
        ),
      );
    }
  }

  Future<void> _terminar() async {
    if (_terminando) return;
    _terminando = true;

    final serie = SerieSenal.de(state.modo, _control?.cuadros ?? const []);
    await _soltar();
    if (isClosed) return;
    emit(state.copiarCon(paso: PasoEscaner.analizando, segundosRestantes: 0));

    final resultado = await _analizador.analizar(serie);
    if (isClosed) return;
    emit(
      resultado.valido
          ? state.copiarCon(paso: PasoEscaner.resultado, resultado: resultado)
          : state.copiarCon(
              paso: PasoEscaner.fallo,
              resultado: resultado,
              fallo: resultado.consejo,
            ),
    );
  }

  /// Detiene la medición con un consejo (la calidad no alcanzó, la cámara
  /// se atascó).
  Future<void> _detener(String consejo) async {
    if (_terminando) return;
    _terminando = true;
    await _soltar();
    if (isClosed) return;
    emit(state.copiarCon(paso: PasoEscaner.fallo, fallo: consejo));
  }

  /// La aplicación pasó a segundo plano en mitad de una medición.
  Future<void> interrumpir() async {
    if (state.paso != PasoEscaner.midiendo &&
        state.paso != PasoEscaner.abriendo) {
      return;
    }
    await _detener(
      'La medición se interrumpió al salir de la aplicación. Vuelve a '
      'intentarlo sin cambiar de pantalla.',
    );
  }

  /// Cancela la medición en curso y vuelve a las instrucciones.
  Future<void> cancelar() async {
    _terminando = true;
    await _soltar();
    if (isClosed) return;
    emit(_enBlanco(state).copiarCon(paso: PasoEscaner.instrucciones));
  }

  /// Suelta la cámara y los números de la medición.
  Future<void> _soltar() async {
    _vigilancia?.cancel();
    _vigilancia = null;
    // Sin esperar: se puede estar dentro de la entrega de un cuadro, y la
    // cancelación termina después; `_terminando` ya descarta lo que llegue.
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    _control = null;
    _estimador.reiniciar();
    _bajaDesde = null;
    rostroEnVivo.value = null;
    await _fuente.cerrar();
  }

  void elegirContexto(ContextoMedicion? contexto) => emit(
    contexto == null
        ? state.copiarCon(limpiarContexto: true)
        : state.copiarCon(contexto: contexto),
  );

  /// «Guardar en mis signos vitales» o, con [destino], «Enviar a mi
  /// médico»: lo mismo, adjunto a la cita o a la consulta.
  Future<void> guardar({DestinoMedico? destino}) async {
    final resultado = state.resultado;
    if (resultado == null || !resultado.valido || state.guardando) return;

    emit(state.copiarCon(guardando: true, limpiarError: true));
    try {
      final registro = await _cola.registrar(
        _uid,
        pacienteId: _pacienteId,
        mediciones: medicionesDelResultado(
          resultado,
          medidoEn: _ahora(),
          contexto: state.contexto,
          destino: destino,
        ),
      );
      if (isClosed) return;
      emit(
        state.copiarCon(
          paso: PasoEscaner.guardado,
          guardando: false,
          registro: registro,
          enviadaA: destino,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copiarCon(
          guardando: false,
          errorAlGuardar: mensajeDeError(
            error,
            generico: 'No pudimos guardar la medición. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// «Descartar»: se olvida el resultado y se vuelve a elegir el modo.
  Future<void> descartar() => volverAModos();

  Future<void> abrirAjustes() => _fuente.abrirAjustes();

  @override
  Future<void> close() async {
    _terminando = true;
    _vigilancia?.cancel();
    await _suscripcion?.cancel();
    _control = null;
    rostroEnVivo.dispose();
    await _fuente.cerrar();
    return super.close();
  }
}
