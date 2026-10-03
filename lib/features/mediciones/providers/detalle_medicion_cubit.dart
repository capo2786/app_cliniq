// lib/features/mediciones/providers/detalle_medicion_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/cola_mediciones.dart';
import '../data/mediciones_service.dart';
import '../data/models/medicion.dart';
import '../presentacion/detalle/ficha_medicion.dart';

/// En qué va la carga de la medición.
enum CargaDetalle {
  /// Pidiendo la medición completa al servidor.
  cargando,

  /// Lista para enseñar (aunque el detalle no haya llegado: ver [error]).
  lista,

  /// No se pudo y no hay nada que enseñar.
  error,

  /// El servidor dice que no existe (borrada, o de otra persona).
  noExiste,
}

class DetalleMedicionState extends Equatable {
  final CargaDetalle carga;

  /// La medición, si ya se tiene (de la lista, de la cola o del servidor).
  final Medicion? medicion;

  /// La otra medición del mismo escaneo (la FR del pulso o al revés).
  final Medicion? companera;

  /// Es un envío pendiente de la cola, con este identificador local.
  final String? idLocal;

  /// Si el servidor lo rechazó al enviarlo, su mensaje.
  final String? rechazo;

  final bool desdeCache;
  final DateTime? guardadaEn;

  /// Por qué no llegó la medición (o su detalle).
  final String? error;

  final bool eliminando;

  /// Ya se eliminó (o se descartó de la cola): la pantalla vuelve.
  final bool eliminada;

  /// Un aviso de una sola vez (no se pudo eliminar).
  final ({String mensaje, int secuencia})? aviso;

  const DetalleMedicionState({
    this.carga = CargaDetalle.cargando,
    this.medicion,
    this.companera,
    this.idLocal,
    this.rechazo,
    this.desdeCache = false,
    this.guardadaEn,
    this.error,
    this.eliminando = false,
    this.eliminada = false,
    this.aviso,
  });

  bool get pendiente => idLocal != null;

  DetalleMedicionState copiarCon({
    CargaDetalle? carga,
    Medicion? medicion,
    bool? desdeCache,
    DateTime? guardadaEn,
    String? error,
    bool limpiarError = false,
    bool? eliminando,
    bool? eliminada,
    ({String mensaje, int secuencia})? aviso,
  }) => DetalleMedicionState(
    carga: carga ?? this.carga,
    medicion: medicion ?? this.medicion,
    companera: companera,
    idLocal: idLocal,
    rechazo: rechazo,
    desdeCache: desdeCache ?? this.desdeCache,
    guardadaEn: guardadaEn ?? this.guardadaEn,
    error: limpiarError ? null : (error ?? this.error),
    eliminando: eliminando ?? this.eliminando,
    eliminada: eliminada ?? this.eliminada,
    aviso: aviso ?? this.aviso,
  );

  @override
  List<Object?> get props => [
    carga,
    medicion,
    companera,
    idLocal,
    rechazo,
    desdeCache,
    guardadaEn,
    error,
    eliminando,
    eliminada,
    aviso,
  ];
}

/// «Detalle de la medición»: una medición guardada (o pendiente de envío).
///
/// Si llega de la lista con lo que hace falta, se enseña sin pedir nada;
/// el pulso de la cámara con `tieneDetalle` (o una medición abierta por su
/// ruta, solo con el identificador) se pide entero con
/// `GET /portal/mediciones/:id`. Sin red, la copia del teléfono; sin copia,
/// lo que vino de la lista con el aviso, o el error. Un 404 es «Esta
/// medición ya no existe».
class DetalleMedicionCubit extends Cubit<DetalleMedicionState> {
  final MedicionesService _servicio;
  final ColaMediciones _cola;
  final String _uid;
  final String _medicionId;

  int _avisos = 0;

  DetalleMedicionCubit({
    required this._servicio,
    required this._cola,
    required this._uid,
    required this._medicionId,
    Medicion? medicion,
    Medicion? companera,
  }) : super(
         DetalleMedicionState(
           carga: hayQuePedirla(medicion)
               ? CargaDetalle.cargando
               : CargaDetalle.lista,
           medicion: medicion,
           companera: companera,
         ),
       );

  /// Un envío de la cola: se enseña con sus datos, detalle incluido.
  DetalleMedicionCubit.pendiente({
    required this._servicio,
    required this._cola,
    required this._uid,
    required EnvioPendiente envio,
  }) : _medicionId = envio.idLocal,
       super(_estadoPendiente(envio));

  static DetalleMedicionState _estadoPendiente(EnvioPendiente envio) {
    final mediciones = medicionesDelEnvio(envio);
    final principal = mediciones.first;
    return DetalleMedicionState(
      carga: CargaDetalle.lista,
      medicion: principal,
      companera: companeraDe(principal, mediciones.skip(1)),
      idLocal: envio.idLocal,
      rechazo: envio.rechazo,
    );
  }

  /// Pide la medición completa si hace falta.
  Future<void> cargar() async {
    if (state.pendiente || !hayQuePedirla(state.medicion)) return;

    emit(state.copiarCon(carga: CargaDetalle.cargando, limpiarError: true));
    try {
      final obtenida = await _servicio.obtener(_uid, _medicionId);
      if (isClosed) return;
      emit(
        state.copiarCon(
          carga: CargaDetalle.lista,
          medicion: obtenida.medicion,
          desdeCache: obtenida.desdeCache,
          guardadaEn: obtenida.guardadaEn,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      if (estadoDe(error) == 404) {
        emit(state.copiarCon(carga: CargaDetalle.noExiste));
        return;
      }
      final mensaje = esFaltaDeRed(error)
          ? 'Sin conexión no pudimos traer el detalle de esta medición.'
          : mensajeDeError(
              error,
              generico: 'No pudimos cargar esta medición. Intenta de nuevo.',
            );
      emit(
        state.copiarCon(
          carga: state.medicion == null
              ? CargaDetalle.error
              : CargaDetalle.lista,
          error: mensaje,
        ),
      );
    }
  }

  /// Elimina la medición (la del servidor, si el médico no la usó) o
  /// descarta el envío pendiente de la cola.
  Future<void> eliminar() async {
    final m = state.medicion;
    if (m == null || state.eliminando) return;

    emit(state.copiarCon(eliminando: true));
    try {
      final idLocal = state.idLocal;
      if (idLocal != null) {
        await _cola.descartar(_uid, idLocal);
      } else {
        await _servicio.eliminar(m.id, uid: _uid);
      }
      if (isClosed) return;
      emit(state.copiarCon(eliminando: false, eliminada: true));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copiarCon(
          eliminando: false,
          aviso: (
            mensaje: mensajeDeError(
              error,
              generico: 'No pudimos eliminar la medición.',
            ),
            secuencia: ++_avisos,
          ),
        ),
      );
    }
  }
}
