import 'package:equatable/equatable.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/archivo_meta.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/models/campo_formulario.dart';
import '../data/models/consulta.dart';
import '../data/models/opciones_consulta.dart';
import '../dominio/reglas_consultas.dart';
import 'consultas_state.dart';

/// Los pasos de una consulta nueva, en orden.
enum PasoConsulta {
  paciente('¿Para quién es la consulta?'),
  especialidad('¿Qué especialidad necesitas?'),
  motivo('¿Cuál es el motivo?'),
  medico('Elige al médico'),
  formulario('Cuéntale al médico'),
  resumen('Revisa y envía'),
  enviada('¡Consulta enviada!');

  final String titulo;

  const PasoConsulta(this.titulo);
}

/// «Para mí» se representa con la cadena vacía, como en el agendamiento.
const String consultaParaMi = '';

/// Un archivo de la consulta: ya subido al borrador, o esperando a subirse
/// al guardar o al enviar.
sealed class AdjuntoConsulta extends Equatable {
  const AdjuntoConsulta();

  String get nombre;
  int get tamano;
  bool get esImagen;
}

/// Elegido en el teléfono; sube al guardar el borrador o al enviar.
class AdjuntoPendiente extends AdjuntoConsulta {
  final ArchivoLocal archivo;

  const AdjuntoPendiente(this.archivo);

  @override
  String get nombre => archivo.nombreParaSubir;

  @override
  int get tamano => archivo.tamano;

  @override
  bool get esImagen => archivo.esImagen;

  @override
  List<Object?> get props => [archivo];
}

/// Ya está en el borrador del servidor.
class AdjuntoSubido extends AdjuntoConsulta {
  final ArchivoMeta archivo;

  const AdjuntoSubido(this.archivo);

  @override
  String get nombre => archivo.nombre;

  @override
  int get tamano => archivo.tamano;

  @override
  bool get esImagen => archivo.esImagen;

  @override
  List<Object?> get props => [archivo];
}

class NuevaConsultaState extends Equatable {
  final PasoConsulta paso;

  // Carga inicial
  final bool cargando;
  final String? error;
  final List<EspecialidadConsulta> especialidades;
  final List<Dependiente> dependientes;
  final bool puedeDependientes;
  final String nombreTitular;

  // Elecciones
  final String para;
  final String? especialidad;
  final MotivoPublico? motivo;
  final MedicoConsulta? medico;

  /// Clave → lo respondido, tal como se edita (los números como texto).
  final Map<String, Object?> respuestas;

  final String descripcion;
  final List<AdjuntoConsulta> adjuntos;

  /// Se intentó seguir con el formulario incompleto: se marcan los errores.
  final bool mostrarErrores;

  // Guardar y enviar
  /// El borrador en el servidor, desde que se guardó por primera vez.
  final ConsultaDetalle? borrador;

  final bool guardando;

  /// Qué se está haciendo mientras se guarda: «Subiendo archivo 1 de 3…».
  final String? progreso;

  final String? errorGuardar;

  /// El archivo que se está quitando del borrador.
  final String? quitandoId;

  final ConsultaDetalle? enviada;

  /// Se borró el borrador: la pantalla se cierra.
  final bool eliminada;

  final AvisoConsultas? aviso;

  const NuevaConsultaState({
    this.paso = PasoConsulta.paciente,
    this.cargando = true,
    this.error,
    this.especialidades = const [],
    this.dependientes = const [],
    this.puedeDependientes = true,
    this.nombreTitular = '',
    this.para = consultaParaMi,
    this.especialidad,
    this.motivo,
    this.medico,
    this.respuestas = const {},
    this.descripcion = '',
    this.adjuntos = const [],
    this.mostrarErrores = false,
    this.borrador,
    this.guardando = false,
    this.progreso,
    this.errorGuardar,
    this.quitandoId,
    this.enviada,
    this.eliminada = false,
    this.aviso,
  });

  /// Ya hay borrador en el servidor: el paciente, el motivo y el médico
  /// quedan fijos, porque el servidor solo deja cambiar las respuestas, la
  /// descripción y los archivos. Para cambiarlos se borra el borrador.
  bool get fijada => borrador != null;

  PasoConsulta get primerPaso {
    if (fijada) return PasoConsulta.formulario;

    return puedeDependientes
        ? PasoConsulta.paciente
        : PasoConsulta.especialidad;
  }

  /// Los pasos de este recorrido, sin el final.
  List<PasoConsulta> get pasosDelRecorrido => [
    for (final p in PasoConsulta.values)
      if (p != PasoConsulta.enviada && p.index >= primerPaso.index) p,
  ];

  EspecialidadConsulta? get especialidadElegida =>
      especialidades.where((e) => e.nombre == especialidad).firstOrNull;

  List<MotivoPublico> get motivosDisponibles =>
      especialidadElegida?.motivosOrdenados ?? const [];

  List<MedicoConsulta> get medicosDisponibles =>
      especialidadElegida?.medicos ?? const [];

  List<CampoFormulario> get campos => motivo?.campos ?? const [];

  String get pacienteNombre {
    final b = borrador;
    if (b != null && b.pacienteNombre.isNotEmpty) return b.pacienteNombre;
    if (para == consultaParaMi) return nombreTitular;

    return dependientes.where((d) => d.uid == para).firstOrNull?.nombre ?? '';
  }

  String get descripcionLimpia => descripcion.trim();

  /// Lo que falta o no vale, por clave (ver `erroresDelFormulario`).
  Map<String, String> get errores => erroresDelFormulario(
    campos: campos,
    respuestas: respuestas,
    descripcion: descripcion,
    requiereAdjunto: motivo?.requiereAdjunto ?? false,
    adjuntos: adjuntos.length,
  );

  int get pendientesDeSubir => adjuntos.whereType<AdjuntoPendiente>().length;

  /// Todo listo para enviar.
  bool get lista =>
      motivo != null && medico != null && errores.isEmpty && !guardando;

  NuevaConsultaState copiarCon({
    PasoConsulta? paso,
    bool? cargando,
    String? error,
    bool limpiarError = false,
    List<EspecialidadConsulta>? especialidades,
    List<Dependiente>? dependientes,
    String? para,
    String? especialidad,
    bool limpiarEspecialidad = false,
    MotivoPublico? motivo,
    bool limpiarMotivo = false,
    MedicoConsulta? medico,
    bool limpiarMedico = false,
    Map<String, Object?>? respuestas,
    String? descripcion,
    List<AdjuntoConsulta>? adjuntos,
    bool? mostrarErrores,
    ConsultaDetalle? borrador,
    bool? guardando,
    String? progreso,
    bool limpiarProgreso = false,
    String? errorGuardar,
    bool limpiarErrorGuardar = false,
    String? quitandoId,
    bool limpiarQuitando = false,
    ConsultaDetalle? enviada,
    bool? eliminada,
    AvisoConsultas? aviso,
  }) {
    return NuevaConsultaState(
      paso: paso ?? this.paso,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
      especialidades: especialidades ?? this.especialidades,
      dependientes: dependientes ?? this.dependientes,
      puedeDependientes: puedeDependientes,
      nombreTitular: nombreTitular,
      para: para ?? this.para,
      especialidad: limpiarEspecialidad
          ? null
          : (especialidad ?? this.especialidad),
      motivo: limpiarMotivo ? null : (motivo ?? this.motivo),
      medico: limpiarMedico ? null : (medico ?? this.medico),
      respuestas: respuestas ?? this.respuestas,
      descripcion: descripcion ?? this.descripcion,
      adjuntos: adjuntos ?? this.adjuntos,
      mostrarErrores: mostrarErrores ?? this.mostrarErrores,
      borrador: borrador ?? this.borrador,
      guardando: guardando ?? this.guardando,
      progreso: limpiarProgreso ? null : (progreso ?? this.progreso),
      errorGuardar: limpiarErrorGuardar
          ? null
          : (errorGuardar ?? this.errorGuardar),
      quitandoId: limpiarQuitando ? null : (quitandoId ?? this.quitandoId),
      enviada: enviada ?? this.enviada,
      eliminada: eliminada ?? this.eliminada,
      aviso: aviso ?? this.aviso,
    );
  }

  @override
  List<Object?> get props => [
    paso,
    cargando,
    error,
    especialidades,
    dependientes,
    puedeDependientes,
    nombreTitular,
    para,
    especialidad,
    motivo,
    medico,
    respuestas,
    descripcion,
    adjuntos,
    mostrarErrores,
    borrador,
    guardando,
    progreso,
    errorGuardar,
    quitandoId,
    enviada,
    eliminada,
    aviso,
  ];
}
