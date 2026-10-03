// lib/features/mediciones/providers/registrar_medicion_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/reglas_mediciones.dart';

class RegistrarMedicionState extends Equatable {
  final TipoMedicion tipo;
  final MetodoMedicion metodo;
  final ContextoMedicion? contexto;

  /// La hora elegida (instante real), o `null` para «ahora».
  final DateTime? medidoEn;

  /// Compartir con el médico de la cita o la consulta desde la que se abrió.
  final bool compartir;

  final bool guardando;
  final ResultadoRegistro? registro;

  /// Por qué no se guardó (lo dice el servidor o la validación).
  final String? error;

  const RegistrarMedicionState({
    this.tipo = TipoMedicion.pa,
    this.metodo = MetodoMedicion.dispositivo,
    this.contexto,
    this.medidoEn,
    this.compartir = true,
    this.guardando = false,
    this.registro,
    this.error,
  });

  RegistrarMedicionState copiarCon({
    TipoMedicion? tipo,
    MetodoMedicion? metodo,
    ContextoMedicion? contexto,
    bool limpiarContexto = false,
    DateTime? medidoEn,
    bool ahora = false,
    bool? compartir,
    bool? guardando,
    ResultadoRegistro? registro,
    String? error,
    bool limpiarError = false,
  }) => RegistrarMedicionState(
    tipo: tipo ?? this.tipo,
    metodo: metodo ?? this.metodo,
    contexto: limpiarContexto ? null : (contexto ?? this.contexto),
    medidoEn: ahora ? null : (medidoEn ?? this.medidoEn),
    compartir: compartir ?? this.compartir,
    guardando: guardando ?? this.guardando,
    registro: registro ?? this.registro,
    error: limpiarError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    tipo,
    metodo,
    contexto,
    medidoEn,
    compartir,
    guardando,
    registro,
    error,
  ];
}

/// El formulario de «Registrar»: qué tipo, cómo, en qué momento y a qué
/// hora; valida con las reglas del servidor y guarda (o, sin red, deja en
/// la cola).
class RegistrarMedicionCubit extends Cubit<RegistrarMedicionState> {
  final ColaMediciones _cola;
  final String _uid;
  final String? _pacienteId;

  /// El instante de ahora (para «ahora» y para validar la hora).
  final DateTime Function() _ahora;

  /// La cita o la consulta desde la que se abrió, si se abrió desde una.
  final String? citaId;
  final String? consultaId;

  RegistrarMedicionCubit({
    required this._cola,
    required this._uid,
    this._pacienteId,
    this.citaId,
    this.consultaId,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? (() => DateTime.now().toUtc()),
       super(const RegistrarMedicionState());

  void elegirTipo(TipoMedicion tipo) {
    final metodos = metodosDelFormulario(tipo);
    final contextos = contextosDelTipo(tipo);
    emit(
      state.copiarCon(
        tipo: tipo,
        metodo: metodos.contains(state.metodo) ? state.metodo : metodos.first,
        contexto: contextos.contains(state.contexto) ? state.contexto : null,
        limpiarContexto: !contextos.contains(state.contexto),
        limpiarError: true,
      ),
    );
  }

  void elegirMetodo(MetodoMedicion metodo) =>
      emit(state.copiarCon(metodo: metodo));

  void elegirContexto(ContextoMedicion? contexto) => emit(
    contexto == null || contexto == state.contexto
        ? state.copiarCon(limpiarContexto: true)
        : state.copiarCon(contexto: contexto),
  );

  /// La hora de la medición; `null` vuelve a «ahora».
  void elegirMomento(DateTime? instante) => emit(
    instante == null
        ? state.copiarCon(ahora: true, limpiarError: true)
        : state.copiarCon(medidoEn: instante.toUtc(), limpiarError: true),
  );

  void alternarCompartir(bool compartir) =>
      emit(state.copiarCon(compartir: compartir));

  /// Valida y guarda. [valor] y [valor2] son lo que escribió la persona.
  Future<void> guardar({
    required String valor,
    String valor2 = '',
    String notas = '',
  }) async {
    if (state.guardando) return;

    final tipo = state.tipo;
    final numero = leerNumero(valor);
    final numero2 = tipo == TipoMedicion.pa ? leerNumero(valor2) : null;
    final problema = validarValores(tipo, numero, numero2);
    if (problema != null) {
      emit(state.copiarCon(error: problema));
      return;
    }

    final ahora = _ahora();
    final medidoEn = state.medidoEn ?? ahora;
    final problemaHora = validarMomento(medidoEn, ahora);
    if (problemaHora != null) {
      emit(state.copiarCon(error: problemaHora));
      return;
    }

    final texto = notas.trim();
    final compartir = state.compartir;
    final medicion = MedicionNueva(
      tipo: tipo,
      valor: numero!,
      valor2: numero2,
      metodo: state.metodo,
      contexto: state.contexto,
      notas: texto.isEmpty ? null : texto,
      medidoEn: medidoEn,
      citaId: compartir ? citaId : null,
      consultaId: compartir ? consultaId : null,
    );

    emit(state.copiarCon(guardando: true, limpiarError: true));
    try {
      final registro = await _cola.registrar(
        _uid,
        pacienteId: _pacienteId,
        mediciones: [medicion],
      );
      if (!isClosed) {
        emit(state.copiarCon(guardando: false, registro: registro));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copiarCon(
            guardando: false,
            error: mensajeDeError(
              error,
              generico: 'No pudimos guardar la medición. Intenta de nuevo.',
            ),
          ),
        );
      }
    }
  }
}
