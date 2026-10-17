// lib/features/clinicas/providers/clinica_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../../core/network/interceptor_de_empresa.dart';
import '../data/almacen_de_clinica.dart';
import '../data/empresas_service.dart';
import '../dominio/clinica.dart';

/// La clínica de la aplicación.
class ClinicaState extends Equatable {
  /// La guardada, o `null`: entonces la API usa su predeterminada.
  final Clinica? clinica;

  /// Cuántas veces cambió de clínica desde que se abrió la aplicación. Lo
  /// escucha quien tiene que volver a pedir lo de la clínica (la
  /// configuración, los catálogos, los legales): un cambio de marca de la
  /// misma clínica no lo sube.
  final int cambios;

  /// El código de la clínica guardada que se acaba de olvidar porque ya no
  /// está disponible (suspendida), para avisarlo una vez. El estado
  /// siguiente ya no lo trae.
  final String? noDisponible;

  const ClinicaState({this.clinica, this.cambios = 0, this.noDisponible});

  @override
  List<Object?> get props => [clinica, cambios, noDisponible];
}

/// Qué pasó al buscar un código.
sealed class ResultadoDeCodigo {
  const ResultadoDeCodigo();
}

/// El código es de esta clínica.
class CodigoEncontrado extends ResultadoDeCodigo {
  final Clinica clinica;

  const CodigoEncontrado(this.clinica);
}

/// No hay ninguna clínica con ese código.
class CodigoDesconocido extends ResultadoDeCodigo {
  const CodigoDesconocido();
}

/// La clínica existe pero no está disponible por ahora (suspendida).
class CodigoNoDisponible extends ResultadoDeCodigo {
  const CodigoNoDisponible();
}

/// No se pudo preguntar (sin red, o el servidor falló).
class CodigoSinRespuesta extends ResultadoDeCodigo {
  final Object error;

  const CodigoSinRespuesta(this.error);
}

/// Lo que se le dice a la persona cuando la clínica de [codigo] está
/// suspendida: al buscar su código, al abrir su enlace de registro o cuando
/// la guardada deja de estar disponible.
String mensajeDeClinicaNoDisponible(String codigo) =>
    'La clínica «${limpiarCodigo(codigo)}» no está disponible por ahora. '
    'Consulta con tu clínica.';

/// Lo que se le dice a la persona de una búsqueda que no encontró su
/// clínica, o `null` si la encontró.
String? mensajeDeBusqueda(
  ResultadoDeCodigo resultado,
  String codigo,
) => switch (resultado) {
  CodigoEncontrado() => null,
  CodigoDesconocido() =>
    'No encontramos ninguna clínica con el código «${limpiarCodigo(codigo)}». '
        'Revísalo con tu clínica.',
  CodigoNoDisponible() => mensajeDeClinicaNoDisponible(codigo),
  CodigoSinRespuesta(:final error) => mensajeDeError(
    error,
    generico: 'No pudimos comprobar el código. Intenta de nuevo.',
  ),
};

/// Guarda la clínica, la pone en `X-Empresa` y avisa cuando cambia.
///
/// Cambia en cuatro momentos: al escribir un código (en el acceso o en el
/// registro), al abrir un enlace de registro con `?clinica=`, al elegir una
/// en el acceso cuando el correo está en varias, y al entrar (la del
/// usuario, que manda). Cerrar sesión no la toca.
///
/// Y se olvida sola si la API dice que la guardada ya no está disponible
/// (ver [alNoEstarDisponible]).
class ClinicaCubit extends Cubit<ClinicaState> {
  final AlmacenDeClinica _almacen;
  final EmpresasService _empresas;

  /// Borra lo guardado que es de la clínica anterior (la configuración, los
  /// catálogos, los legales): no tiene que verse en la nueva ni sin red.
  final Future<void> Function() _olvidarDatosDeLaClinica;

  /// Con [inicial], la que ya se leyó del teléfono antes de abrir (ver
  /// `main.dart`): así la primera petición ya lleva la cabecera.
  ClinicaCubit({
    required this._almacen,
    required this._empresas,
    Future<void> Function()? olvidarDatosDeLaClinica,
    Clinica? inicial,
  }) : _olvidarDatosDeLaClinica = olvidarDatosDeLaClinica ?? (() async {}),
       super(ClinicaState(clinica: inicial)) {
    EmpresaDeLasPeticiones.codigo = inicial?.codigo;
    EmpresaDeLasPeticiones.alNoEstarDisponible = alNoEstarDisponible;
  }

  Future<void>? _olvidandoLaNoDisponible;

  Clinica? get clinica => state.clinica;

  /// Lee la guardada. Para cuando no se pudo pasar como [inicial].
  Future<void> cargar() async {
    final guardada = await _almacen.leer();
    if (isClosed || guardada == null || state.clinica != null) return;

    EmpresaDeLasPeticiones.codigo = guardada.codigo;
    emit(ClinicaState(clinica: guardada, cambios: state.cambios));
  }

  /// Busca la clínica de [codigo], sin elegirla todavía: primero se enseña
  /// su nombre y su logotipo, y se elige con [elegir].
  Future<ResultadoDeCodigo> buscar(String codigo) async {
    try {
      final clinica = await _empresas.buscar(codigo);
      return clinica == null
          ? const CodigoDesconocido()
          : CodigoEncontrado(clinica);
    } on ClinicaNoDisponible {
      return const CodigoNoDisponible();
    } catch (error) {
      return CodigoSinRespuesta(error);
    }
  }

  /// Deja elegida [clinica] y la guarda. Si es otra, olvida lo de la
  /// anterior y lo avisa con [ClinicaState.cambios].
  Future<void> elegir(Clinica clinica) async {
    final actual = state.clinica;
    final esOtra = !clinica.esLaMismaQue(actual);
    // De la misma clínica vale lo que dice el servidor ahora (su código,
    // con sus mayúsculas, y su nombre); lo que no trae se conserva.
    final conCodigo = esOtra || actual == null
        ? clinica
        : Clinica(
            codigo: clinica.codigo,
            nombre: clinica.nombre,
            logoUrl: clinica.logoUrl ?? actual.logoUrl,
            colorPrimario: clinica.colorPrimario ?? actual.colorPrimario,
            colorAcento: clinica.colorAcento ?? actual.colorAcento,
          );

    EmpresaDeLasPeticiones.codigo = conCodigo.codigo;
    if (esOtra) await _olvidar();

    await _almacen.guardar(conCodigo);
    if (isClosed) return;

    emit(
      ClinicaState(
        clinica: conCodigo,
        cambios: esOtra ? state.cambios + 1 : state.cambios,
      ),
    );
  }

  /// «No sé el código de mi clínica»: sin clínica guardada, la API la busca
  /// por el correo al entrar (y si no, usa la predeterminada).
  Future<void> olvidar() => _quitar();

  /// La guardada respondió 403 «Esta clínica no está disponible» (está
  /// suspendida): se olvida como al cambiar de clínica —lo guardado de
  /// ella, la cabecera— y se sigue con la predeterminada, como hace el
  /// panel. [ClinicaState.noDisponible] queda con su código para avisarlo.
  ///
  /// Lo llama el interceptor de la clínica (ver
  /// `EmpresaDeLasPeticiones.alNoEstarDisponible`), a veces varias peticiones
  /// a la vez: se olvida una sola vez. Si [codigo] no es el de la guardada
  /// (ya se olvidó, o la petición llevaba otra), no hace nada.
  Future<void> alNoEstarDisponible(String codigo) {
    final enCurso = _olvidandoLaNoDisponible;
    if (enCurso != null) return enCurso;
    if (!mismoCodigo(state.clinica?.codigo, codigo)) return Future.value();

    return _olvidandoLaNoDisponible = _quitar(
      noDisponible: state.clinica!.codigo,
    ).whenComplete(() => _olvidandoLaNoDisponible = null);
  }

  /// Al entrar: la clínica de la cuenta es la que manda. Sin ella (un
  /// servidor anterior) se queda la que había.
  Future<void> alEntrar(Clinica? deLaCuenta) async {
    if (deLaCuenta == null) return;
    await elegir(deLaCuenta);
  }

  /// Copia en la guardada el nombre, el logotipo y los colores que trae la
  /// configuración pública de la clínica: la próxima pantalla previa al
  /// acceso los tiene sin esperar.
  Future<void> actualizarMarca({
    required String nombre,
    String? logoUrl,
    String? colorPrimario,
    String? colorAcento,
  }) async {
    final actual = state.clinica;
    if (actual == null) return;

    final nueva = actual.conMarca(
      nombre: nombre,
      logoUrl: logoUrl,
      colorPrimario: colorPrimario,
      colorAcento: colorAcento,
    );
    if (nueva == actual) return;

    await _almacen.guardar(nueva);
    if (isClosed || !nueva.esLaMismaQue(state.clinica)) return;

    emit(ClinicaState(clinica: nueva, cambios: state.cambios));
  }

  Future<void> _quitar({String? noDisponible}) async {
    if (state.clinica == null) return;

    EmpresaDeLasPeticiones.codigo = null;
    await _olvidar();
    await _almacen.borrar();
    if (isClosed) return;

    emit(ClinicaState(cambios: state.cambios + 1, noDisponible: noDisponible));
  }

  @override
  Future<void> close() {
    if (EmpresaDeLasPeticiones.alNoEstarDisponible == alNoEstarDisponible) {
      EmpresaDeLasPeticiones.alNoEstarDisponible = null;
    }
    return super.close();
  }

  Future<void> _olvidar() async {
    try {
      await _olvidarDatosDeLaClinica();
    } catch (error) {
      debugPrint('Cliniq · no se pudo olvidar la clínica anterior: $error');
    }
  }
}
