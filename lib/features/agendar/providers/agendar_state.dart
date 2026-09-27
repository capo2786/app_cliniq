import 'package:equatable/equatable.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../citas/data/models/cita.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/models/medico_portal.dart';
import '../dominio/horarios.dart';
import '../dominio/huecos.dart';

/// Los pasos del agendamiento, en orden.
enum PasoAgendar {
  paciente('¿Para quién?'),
  filtros('¿Qué necesitas?'),
  medico('Elige al médico'),
  modalidad('¿Cómo quieres la consulta?'),
  horario('Elige día y hora'),
  motivo('Motivo de la consulta'),
  resumen('Revisa y confirma'),
  listo('¡Listo!');

  final String titulo;

  const PasoAgendar(this.titulo);
}

/// En qué situación está el día elegido.
enum EstadoDia {
  sinMedico,
  sinFecha,
  pasado,
  bloqueado,
  noAtiende,
  cargando,
  error,
  limite,
  ok,
}

/// «Para mí» se representa con la cadena vacía, como en el web.
const String paraMi = '';

/// El motivo de consulta admite hasta 500 caracteres (igual que el web).
const int maximoMotivo = 500;

class AgendarState extends Equatable {
  final PasoAgendar paso;

  /// Las reglas de la rejilla, de la configuración de la clínica.
  final ReglasAgendamiento reglas;

  // Carga inicial
  final bool cargando;
  final String? error;
  final List<MedicoPortal> medicos;

  /// Los catálogos `ESPECIALIDAD` y `CIUDAD`: solo dan el orden de los
  /// filtros (las opciones son las que tienen médicos).
  final List<String> especialidades;
  final List<String> catalogoCiudades;
  final List<Dependiente> dependientes;
  final bool puedeDependientes;
  final String nombreTitular;

  // Elecciones
  final String para;
  final String filtroEspecialidad;
  final String filtroCiudad;
  final TipoCita? filtroModalidad;
  final String? medicoId;
  final TipoCita tipo;
  final DateTime? fecha;
  final Hueco? hueco;
  final String motivo;

  /// La cita que se reprograma, o `null` al agendar una nueva.
  final Cita? original;

  // Lo ocupado del médico el día elegido
  final List<IntervaloOcupado> ocupados;
  final bool cargandoOcupados;
  final String? errorOcupados;

  // Guardar
  final bool guardando;
  final String? errorGuardar;
  final Cita? agendada;

  /// Un aviso de paso: «ese horario acaba de ocuparse».
  final String? aviso;

  /// La hora de la clínica cuando se armó este estado.
  final DateTime ahora;

  const AgendarState({
    required this.ahora,
    required this.reglas,
    this.paso = PasoAgendar.paciente,
    this.cargando = true,
    this.error,
    this.medicos = const [],
    this.especialidades = const [],
    this.catalogoCiudades = const [],
    this.dependientes = const [],
    this.puedeDependientes = true,
    this.nombreTitular = '',
    this.para = paraMi,
    this.filtroEspecialidad = '',
    this.filtroCiudad = '',
    this.filtroModalidad,
    this.medicoId,
    this.tipo = TipoCita.presencial,
    this.fecha,
    this.hueco,
    this.motivo = '',
    this.original,
    this.ocupados = const [],
    this.cargandoOcupados = false,
    this.errorOcupados,
    this.guardando = false,
    this.errorGuardar,
    this.agendada,
    this.aviso,
  });

  bool get reprogramando => original != null;

  /// El primer paso de este recorrido: al reprogramar se entra directo a
  /// elegir la hora, con el mismo médico y la misma modalidad.
  PasoAgendar get primerPaso => reprogramando
      ? PasoAgendar.horario
      : (puedeDependientes ? PasoAgendar.paciente : PasoAgendar.filtros);

  MedicoPortal? get medico =>
      medicos.where((m) => m.uid == medicoId).firstOrNull;

  /// Las ciudades donde hay médicos, en el orden del catálogo `CIUDAD`; las
  /// que no están en el catálogo van al final, en orden alfabético.
  List<String> get ciudades =>
      _conMedicos(catalogoCiudades, [for (final m in medicos) m.ciudad]);

  /// Las especialidades que tienen al menos un médico, en el orden del
  /// catálogo; las que no están en el catálogo van al final.
  ///
  /// El web ofrece el catálogo entero. En un teléfono, elegir una
  /// especialidad sin médicos es un callejón sin salida, así que solo se
  /// ofrecen las que llevan a alguien.
  List<String> get especialidadesConMedicos =>
      _conMedicos(especialidades, [for (final m in medicos) m.especialidad]);

  static List<String> _conMedicos(
    List<String> catalogo,
    List<String?> deLosMedicos,
  ) {
    final presentes = {
      for (final valor in deLosMedicos)
        if (valor != null && valor.trim().isNotEmpty)
          normalizarTexto(valor): valor.trim(),
    };

    final ordenadas = <String>[
      for (final e in catalogo)
        if (presentes.remove(normalizarTexto(e)) != null) e,
    ];

    final resto = presentes.values.toList()
      ..sort((a, b) => normalizarTexto(a).compareTo(normalizarTexto(b)));

    return [...ordenadas, ...resto];
  }

  List<MedicoPortal> get medicosFiltrados {
    final esp = normalizarTexto(filtroEspecialidad);
    final ciudad = normalizarTexto(filtroCiudad);
    final modalidad = filtroModalidad;

    return medicos
        .where(
          (m) =>
              (esp.isEmpty || normalizarTexto(m.especialidad) == esp) &&
              (ciudad.isEmpty || normalizarTexto(m.ciudad) == ciudad) &&
              (modalidad == null || m.modalidadesOfrecidas.contains(modalidad)),
        )
        .toList();
  }

  List<TipoCita> get modalidadesMedico =>
      medico?.modalidadesOfrecidas ?? const [];

  String get pacienteNombre {
    if (para == paraMi) return nombreTitular;

    return dependientes.where((d) => d.uid == para).firstOrNull?.nombre ?? '';
  }

  int get duracion => duracionDe(medico, tipo, reglas);

  BloqueoAgenda? get bloqueo {
    final f = fecha;
    return f == null ? null : bloqueoEn(medico, f);
  }

  List<HorarioRango> get _rangos {
    final f = fecha;
    final m = medico;

    return f != null && m != null
        ? rangosDelDia(m.horariosAtencion, f)
        : const [];
  }

  /// Lo ocupado sin la propia cita que se reprograma: su horario queda libre.
  List<IntervaloOcupado> get ocupadosSinOriginal {
    final o = original;
    if (o == null) return ocupados;

    return ocupados
        .where((c) => !(c.inicio == o.inicio && c.fin == o.fin))
        .toList();
  }

  EstadoDia get estadoDia {
    final f = fecha;

    if (medico == null) return EstadoDia.sinMedico;
    if (f == null) return EstadoDia.sinFecha;
    if (f.isBefore(inicioDelDia(ahora))) return EstadoDia.pasado;
    if (bloqueo != null) return EstadoDia.bloqueado;
    if (_rangos.isEmpty) return EstadoDia.noAtiende;
    if (cargandoOcupados) return EstadoDia.cargando;
    if (errorOcupados != null) return EstadoDia.error;
    if (limiteAlcanzado(medico, ocupadosSinOriginal, f)) {
      return EstadoDia.limite;
    }

    return EstadoDia.ok;
  }

  List<Hueco> get huecos {
    final f = fecha;
    if (f == null || estadoDia != EstadoDia.ok) return const [];

    return calcularHuecos(
      fecha: f,
      rangos: _rangos,
      duracion: duracion,
      margen: margenDe(medico),
      citas: ocupadosSinOriginal,
      ahora: ahoraConAnticipacion(ahora, reglas),
      reglas: reglas,
    );
  }

  Map<Periodo, List<Hueco>> get grupos => agruparPorPeriodo(huecos);

  int get libres => huecos.where((h) => !h.ocupado).length;

  /// El horario elegido, solo mientras siga libre y válido.
  Hueco? get huecoValido {
    final h = hueco;
    if (h == null) return null;

    return huecos.any((x) => x.hora == h.hora && !x.ocupado) ? h : null;
  }

  /// El primer día que se ofrece: hoy si todavía cabe una cita.
  DateTime? get primerDia {
    final m = medico;
    return m == null ? null : primerDiaConAtencion(m, duracion, ahora, reglas);
  }

  /// Los días de la tira: los próximos con atención desde el primero.
  List<DateTime> get diasDisponibles {
    final m = medico;
    final primero = primerDia;
    if (m == null || primero == null) return const [];

    final dias = diasConAtencion(
      m,
      primero,
      reglas: reglas,
      hasta: sumarDias(inicioDelDia(ahora), reglas.diasHorizonte),
    );
    final f = fecha;

    // Si el día elegido quedó fuera (la cita original, por ejemplo), se
    // agrega para que siempre se vea marcado.
    if (f != null && !dias.any((d) => mismoDia(d, f))) {
      return [...dias, f]..sort();
    }

    return dias;
  }

  String get motivoLimpio => motivo.trim();

  bool get motivoValido =>
      motivoLimpio.isNotEmpty && motivoLimpio.length <= maximoMotivo;

  /// Lo que falta para poder confirmar, en palabras.
  List<String> get faltantes => [
    if (medico == null) 'médico',
    if (huecoValido == null) 'horario',
    if (!reprogramando && !motivoValido) 'motivo',
  ];

  bool get listo => faltantes.isEmpty && !guardando;

  AgendarState copiarCon({
    PasoAgendar? paso,
    bool? cargando,
    String? error,
    bool limpiarError = false,
    List<MedicoPortal>? medicos,
    List<String>? especialidades,
    List<String>? catalogoCiudades,
    List<Dependiente>? dependientes,
    bool? puedeDependientes,
    String? nombreTitular,
    String? para,
    String? filtroEspecialidad,
    String? filtroCiudad,
    TipoCita? filtroModalidad,
    bool limpiarFiltroModalidad = false,
    String? medicoId,
    TipoCita? tipo,
    DateTime? fecha,
    bool limpiarFecha = false,
    Hueco? hueco,
    bool limpiarHueco = false,
    String? motivo,
    Cita? original,
    bool limpiarOriginal = false,
    List<IntervaloOcupado>? ocupados,
    bool? cargandoOcupados,
    String? errorOcupados,
    bool limpiarErrorOcupados = false,
    bool? guardando,
    String? errorGuardar,
    bool limpiarErrorGuardar = false,
    Cita? agendada,
    bool limpiarAgendada = false,
    String? aviso,
    bool limpiarAviso = false,
    DateTime? ahora,
  }) {
    return AgendarState(
      reglas: reglas,
      paso: paso ?? this.paso,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
      medicos: medicos ?? this.medicos,
      especialidades: especialidades ?? this.especialidades,
      catalogoCiudades: catalogoCiudades ?? this.catalogoCiudades,
      dependientes: dependientes ?? this.dependientes,
      puedeDependientes: puedeDependientes ?? this.puedeDependientes,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      para: para ?? this.para,
      filtroEspecialidad: filtroEspecialidad ?? this.filtroEspecialidad,
      filtroCiudad: filtroCiudad ?? this.filtroCiudad,
      filtroModalidad: limpiarFiltroModalidad
          ? null
          : (filtroModalidad ?? this.filtroModalidad),
      medicoId: medicoId ?? this.medicoId,
      tipo: tipo ?? this.tipo,
      fecha: limpiarFecha ? null : (fecha ?? this.fecha),
      hueco: limpiarHueco ? null : (hueco ?? this.hueco),
      motivo: motivo ?? this.motivo,
      original: limpiarOriginal ? null : (original ?? this.original),
      ocupados: ocupados ?? this.ocupados,
      cargandoOcupados: cargandoOcupados ?? this.cargandoOcupados,
      errorOcupados: limpiarErrorOcupados
          ? null
          : (errorOcupados ?? this.errorOcupados),
      guardando: guardando ?? this.guardando,
      errorGuardar: limpiarErrorGuardar
          ? null
          : (errorGuardar ?? this.errorGuardar),
      agendada: limpiarAgendada ? null : (agendada ?? this.agendada),
      aviso: limpiarAviso ? null : (aviso ?? this.aviso),
      ahora: ahora ?? this.ahora,
    );
  }

  @override
  List<Object?> get props => [
    reglas,
    paso,
    cargando,
    error,
    medicos,
    especialidades,
    catalogoCiudades,
    dependientes,
    puedeDependientes,
    nombreTitular,
    para,
    filtroEspecialidad,
    filtroCiudad,
    filtroModalidad,
    medicoId,
    tipo,
    fecha,
    hueco,
    motivo,
    original,
    ocupados,
    cargandoOcupados,
    errorOcupados,
    guardando,
    errorGuardar,
    agendada,
    aviso,
    ahora,
  ];
}

/// Quita tildes y mayúsculas: «Pediatría» se encuentra escribiendo
/// «pediatria» (igual que `normalizarTexto` del web).
String normalizarTexto(String? texto) {
  const conTilde = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sinTilde = 'aaaaaeeeeiiiiooooouuuunc';

  final minusculas = (texto ?? '').toLowerCase().trim();
  final buffer = StringBuffer();

  for (final letra in minusculas.split('')) {
    final i = conTilde.indexOf(letra);
    buffer.write(i < 0 ? letra : sinTilde[i]);
  }

  return buffer.toString();
}
