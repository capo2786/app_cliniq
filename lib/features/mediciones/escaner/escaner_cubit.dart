// lib/features/mediciones/escaner/escaner_cubit.dart

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import 'analizador_de_medicion.dart';
import 'aviso_experimental.dart';
import 'fuente_de_cuadros.dart';
import 'motor_signos_camara.dart';
import 'escaner_state.dart';
import 'serie_senal.dart';

export 'escaner_state.dart';

/// El escáner experimental, paso a paso.
///
/// Los cuadros que llegan de la [FuenteDeCuadros] ya son números; se
/// juntan en un buffer solo mientras dura la medición y se sueltan al
/// terminar, al cancelar o al descartar. La cuenta regresiva va con el
/// tiempo de los propios cuadros (no con un reloj aparte): si la cámara se
/// atasca, la cuenta se para y, a los [plazoSinCuadros], se avisa.
///
/// Mientras mide, cada medio segundo pide al motor la calidad en vivo y el
/// consejo («Cubre bien la cámara», «Quédate quieto», «Más luz»). Si la
/// calidad se queda por debajo de [calidadParaSeguir] durante
/// [segundosDeCalidadBaja], se detiene con un consejo y «Reintentar».
class EscanerCubit extends Cubit<EscanerState> {
  final FuenteDeCuadros _fuente;
  final MotorSignosCamara _motor;
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

  final List<CuadroPpg> _cuadros = [];
  StreamSubscription<CuadroPpg>? _suscripcion;
  Timer? _vigilancia;
  DateTime _ultimoCuadro = DateTime.now();
  double _ultimaLectura = -1;
  double? _bajaDesde;
  bool _terminando = false;

  EscanerCubit({
    required this._fuente,
    required this._motor,
    required this._analizador,
    required this._cola,
    required this._aviso,
    required this._uid,
    required int segundos,
    this._pacienteId,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now,
       super(EscanerState(segundos: segundos, segundosRestantes: segundos));

  /// La fuente, para pintar su vista previa.
  FuenteDeCuadros get fuente => _fuente;

  /// Al abrir: el aviso la primera vez; después, elegir el modo.
  Future<void> iniciar() async {
    final aceptado = await _aviso.aceptado(_uid);
    if (isClosed) return;
    emit(
      state.copiarCon(paso: aceptado ? PasoEscaner.modo : PasoEscaner.aviso),
    );
  }

  Future<void> aceptarAviso() async {
    await _aviso.aceptar(_uid);
    if (!isClosed) emit(state.copiarCon(paso: PasoEscaner.modo));
  }

  void elegirModo(ModoEscaner modo) =>
      emit(state.copiarCon(paso: PasoEscaner.instrucciones, modo: modo));

  /// Vuelve a elegir el modo, soltando lo que hubiera.
  Future<void> volverAModos() async {
    await _soltar();
    if (isClosed) return;
    emit(
      state.copiarCon(
        paso: PasoEscaner.modo,
        limpiarResultado: true,
        limpiarFallo: true,
        limpiarContexto: true,
        limpiarRegistro: true,
        limpiarError: true,
        lectura: const LecturaEnVivo(),
      ),
    );
  }

  /// Abre la cámara y empieza a medir.
  Future<void> empezar() async {
    await _soltar();
    if (isClosed) return;
    emit(
      state.copiarCon(
        paso: PasoEscaner.abriendo,
        segundosRestantes: state.segundos,
        lectura: const LecturaEnVivo(),
        limpiarResultado: true,
        limpiarFallo: true,
        limpiarRegistro: true,
        limpiarError: true,
      ),
    );

    _terminando = false;
    try {
      _suscripcion = _fuente.cuadros.listen(_alCuadro);
      await _fuente.abrir(state.modo);
    } on ErrorDeCamara catch (error) {
      await _soltar();
      if (isClosed) return;
      emit(
        state.copiarCon(
          paso: PasoEscaner.fallo,
          fallo: error.mensaje,
          fallaPorPermiso: error.motivo == MotivoErrorCamara.permisoBloqueado,
        ),
      );
      return;
    } catch (_) {
      await _soltar();
      if (isClosed) return;
      emit(
        state.copiarCon(
          paso: PasoEscaner.fallo,
          fallo: const ErrorDeCamara(MotivoErrorCamara.otro).mensaje,
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
    if (isClosed || _terminando || state.paso != PasoEscaner.midiendo) return;

    _ultimoCuadro = DateTime.now();
    _cuadros.add(cuadro);
    final transcurrido = cuadro.segundos - _cuadros.first.segundos;
    final restantes = (state.segundos - transcurrido).ceil().clamp(
      0,
      state.segundos,
    );

    if (transcurrido - _ultimaLectura >= 0.5) {
      _ultimaLectura = transcurrido;
      final lectura = _motor.enVivo(SerieSenal.de(state.modo, _cuadros));
      _vigilarCalidad(lectura, transcurrido);
      if (isClosed || _terminando) return;
      emit(state.copiarCon(segundosRestantes: restantes, lectura: lectura));
    } else if (restantes != state.segundosRestantes) {
      emit(state.copiarCon(segundosRestantes: restantes));
    }

    if (transcurrido >= state.segundos) unawaited(_terminar());
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

    final serie = SerieSenal.de(state.modo, _cuadros);
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
    emit(
      state.copiarCon(
        paso: PasoEscaner.instrucciones,
        lectura: const LecturaEnVivo(),
        segundosRestantes: state.segundos,
      ),
    );
  }

  /// Suelta la cámara y los números de la medición.
  Future<void> _soltar() async {
    _vigilancia?.cancel();
    _vigilancia = null;
    // Sin esperar: se puede estar dentro de la entrega de un cuadro, y la
    // cancelación termina después; `_terminando` ya descarta lo que llegue.
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    _cuadros.clear();
    _ultimaLectura = -1;
    _bajaDesde = null;
    await _fuente.cerrar();
  }

  void elegirContexto(ContextoMedicion? contexto) => emit(
    contexto == null
        ? state.copiarCon(limpiarContexto: true)
        : state.copiarCon(contexto: contexto),
  );

  /// Las mediciones del resultado: la FC y, si salió, la FR, con el método
  /// de la cámara, la calidad y el motor en las notas.
  List<MedicionNueva> _mediciones(ResultadoEscaner r, DestinoMedico? destino) {
    final medidoEn = _ahora().toUtc();
    MedicionNueva una(TipoMedicion tipo, int valor) => MedicionNueva(
      tipo: tipo,
      valor: valor,
      metodo: r.modo.metodo,
      calidad: double.parse(r.calidad.toStringAsFixed(2)),
      contexto: state.contexto,
      notas: r.notas,
      medidoEn: medidoEn,
      citaId: destino?.citaId,
      consultaId: destino?.consultaId,
    );

    return [
      una(TipoMedicion.fc, r.fc!),
      if (r.fr != null) una(TipoMedicion.fr, r.fr!),
    ];
  }

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
        mediciones: _mediciones(resultado, destino),
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
    _cuadros.clear();
    await _fuente.cerrar();
    return super.close();
  }
}
