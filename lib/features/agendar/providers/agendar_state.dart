import 'package:equatable/equatable.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../citas/data/models/cita.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/models/medico_portal.dart';
import '../data/models/turnos.dart';
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

/// En qué situación está la rejilla de horarios.
enum EstadoDia {
  /// Todavía no hay médico elegido.
  sinMedico,

  /// Se están pidiendo los turnos del médico.
  cargando,

  /// No se pudieron pedir.
  error,

  /// El médico no tiene ningún turno libre dentro del horizonte.
  sinTurnos,

  /// Hay turnos, pero no hay día elegido.
  sinFecha,

  /// El día elegido no tiene turnos libres.
  diaSinTurnos,

  ok,
}

/// «Para mí» se representa con la cadena vacía, como en el web.
const String paraMi = '';

/// El motivo de consulta admite hasta 500 caracteres (igual que el web).
const int maximoMotivo = 500;

/// «El primer turno disponible»: con qué médico y cuándo.
typedef PrimerTurno = ({MedicoPortal medico, ProximoTurno turno});

class AgendarState extends Equatable {
  final PasoAgendar paso;

  /// Las reglas de la clínica: los cortes de mañana, tarde y noche, la
  /// anticipación y las duraciones por defecto.
  final ReglasAgendamiento reglas;

  // Carga inicial
  final bool cargando;
  final String? error;

  /// Los médicos con turnos libres (`/portal/proximos-turnos`), del turno
  /// más cercano al más lejano, con los filtros de ciudad y modalidad.
  final List<MedicoPortal> medicos;

  /// Las especialidades con médicos que tienen turnos libres, en el orden
  /// del catálogo, con cuántos médicos y su primer turno.
  final List<EspecialidadDisponible> especialidades;

  /// El catálogo `CIUDAD`: solo da el orden del filtro.
  final List<String> catalogoCiudades;

  /// Las ciudades donde hay médicos con turnos libres, para el filtro.
  final List<String> ciudades;

  // Recarga de los próximos turnos (al filtrar o después de un choque)
  final bool cargandoProximos;
  final String? errorProximos;

  final List<Dependiente> dependientes;
  final bool puedeDependientes;
  final String nombreTitular;

  // Elecciones
  final String para;
  final String filtroEspecialidad;
  final String filtroCiudad;
  final TipoCita? filtroModalidad;

  /// Lo escrito en el buscador de médicos.
  final String busqueda;

  /// El médico elegido. Se guarda entero, y no solo su id, para que siga
  /// ahí aunque la lista de médicos se recargue sin él.
  final MedicoPortal? medico;
  final TipoCita tipo;
  final DateTime? fecha;
  final Hueco? hueco;
  final String motivo;

  /// La cita que se reprograma, o `null` al agendar una nueva.
  final Cita? original;

  // Los turnos libres del médico en la modalidad elegida
  final TurnosMedico? turnos;
  final bool cargandoTurnos;
  final String? errorTurnos;

  /// Los turnos que el servidor rechazó por estar tomados
  /// (`doctorId@AAAA-MM-DDTHH:mm:ss`). No se vuelven a ofrecer en esta
  /// visita aunque una respuesta los traiga.
  final Set<String> descartados;

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
    this.ciudades = const [],
    this.cargandoProximos = false,
    this.errorProximos,
    this.dependientes = const [],
    this.puedeDependientes = true,
    this.nombreTitular = '',
    this.para = paraMi,
    this.filtroEspecialidad = '',
    this.filtroCiudad = '',
    this.filtroModalidad,
    this.busqueda = '',
    this.medico,
    this.tipo = TipoCita.presencial,
    this.fecha,
    this.hueco,
    this.motivo = '',
    this.original,
    this.turnos,
    this.cargandoTurnos = false,
    this.errorTurnos,
    this.descartados = const {},
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

  String? get medicoId => medico?.uid;

  /// Las ciudades en el orden del catálogo `CIUDAD`; las que no están en el
  /// catálogo van al final, en orden alfabético.
  static List<String> ordenarCiudades(
    List<String> catalogo,
    List<MedicoPortal> medicos,
  ) {
    final presentes = {
      for (final m in medicos)
        if (m.ciudad != null && m.ciudad!.trim().isNotEmpty)
          normalizarTexto(m.ciudad): m.ciudad!.trim(),
    };

    final ordenadas = <String>[
      for (final c in catalogo)
        if (presentes.remove(normalizarTexto(c)) != null) c,
    ];

    final resto = presentes.values.toList()
      ..sort((a, b) => normalizarTexto(a).compareTo(normalizarTexto(b)));

    return [...ordenadas, ...resto];
  }

  // ── Especialidades y médicos ───────────────────────────────────────

  /// La especialidad elegida, o `null` si se eligió ver todas.
  EspecialidadDisponible? get especialidadElegida {
    final elegida = normalizarTexto(filtroEspecialidad);
    if (elegida.isEmpty) return null;

    return especialidades
        .where((e) => normalizarTexto(e.nombre) == elegida)
        .firstOrNull;
  }

  /// Los médicos de la especialidad elegida (o todos), sin el buscador.
  ///
  /// La ciudad y la modalidad ya las filtra la API; se vuelven a mirar aquí
  /// por si la lista es de antes de cambiar un filtro.
  List<MedicoPortal> get medicosDeLaEspecialidad {
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

  /// Los de la especialidad que coinciden con el buscador: cada palabra
  /// escrita tiene que estar en el nombre, sin importar tildes ni
  /// mayúsculas.
  List<MedicoPortal> get medicosFiltrados {
    final palabras = normalizarTexto(busqueda)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final todos = medicosDeLaEspecialidad;
    if (palabras.isEmpty) return todos;

    return todos.where((m) {
      final nombre = normalizarTexto(m.nombre);
      return palabras.every(nombre.contains);
    }).toList();
  }

  /// «El primer turno disponible» de la especialidad elegida —el que manda
  /// la API para ella— o, con todas, el más cercano de cualquier médico.
  PrimerTurno? get primerTurno {
    final delaEspecialidad = especialidadElegida?.proximo;
    final doctorId = delaEspecialidad?.doctorId;

    if (delaEspecialidad != null && doctorId != null) {
      final medico = medicosDeLaEspecialidad
          .where((m) => m.uid == doctorId)
          .firstOrNull;
      if (medico != null) return (medico: medico, turno: delaEspecialidad);
    }

    return _primeroDe(medicosDeLaEspecialidad);
  }

  /// Si se está confirmando «El primer turno disponible» contra la API: ya
  /// hay turno elegido y se piden los turnos del médico sin salir del paso.
  bool get confirmandoPrimerTurno =>
      paso == PasoAgendar.medico && cargandoTurnos && hueco != null;

  /// El turno más cercano entre todos los médicos (para «Todas las
  /// especialidades»).
  PrimerTurno? get primerTurnoGeneral => _primeroDe(medicos);

  static PrimerTurno? _primeroDe(List<MedicoPortal> medicos) {
    PrimerTurno? primero;

    for (final m in medicos) {
      final proximo = m.proximo;
      if (proximo == null) continue;
      if (primero == null || proximo.inicio.isBefore(primero.turno.inicio)) {
        primero = (medico: m, turno: proximo.conMedico(m.uid));
      }
    }

    return primero;
  }

  List<TipoCita> get modalidadesMedico =>
      medico?.modalidadesOfrecidas ?? const [];

  String get pacienteNombre {
    if (para == paraMi) return nombreTitular;

    return dependientes.where((d) => d.uid == para).firstOrNull?.nombre ?? '';
  }

  /// El dependiente para quien se piden los turnos (`pacienteId`): la API
  /// quita los que chocan con sus propias citas. Para el titular, `null`.
  ///
  /// Al reprogramar es el de la cita, si era de un dependiente.
  String? get pacienteIdTurnos {
    final o = original;
    if (o != null) {
      final id = o.pacienteId ?? '';
      return o.paraDependiente && id.isNotEmpty ? id : null;
    }

    return para == paraMi ? null : para;
  }

  // ── Turnos del médico ──────────────────────────────────────────────

  /// Los turnos cargados, solo si son del médico, la modalidad y el
  /// paciente elegidos.
  TurnosMedico? get turnosActuales {
    final t = turnos;
    final m = medico;

    return t != null &&
            m != null &&
            t.doctorId == m.uid &&
            t.modalidad == tipo &&
            t.pacienteId == pacienteIdTurnos
        ? t
        : null;
  }

  /// Minutos de la cita: los que dice la API para estos turnos o, mientras
  /// no llegan, los del médico o la clínica.
  int get duracion {
    final deLaApi = turnosActuales?.duracion ?? 0;

    return deLaApi > 0 ? deLaApi : duracionDe(medico, tipo, reglas);
  }

  /// `pacienteId|doctorId@AAAA-MM-DDTHH:mm:ss` (sin paciente para el
  /// titular); sin [inicio], solo el prefijo. Va con el paciente porque un
  /// turno puede chocar con una cita suya y no con las de otro.
  static String claveDescartado(
    String? pacienteId,
    String doctorId,
    DateTime? inicio,
  ) =>
      '${pacienteId ?? ''}|$doctorId@${inicio == null ? '' : aTextoLocal(inicio)}';

  /// Los turnos que todavía se pueden ofrecer: sin los que ya pasaron (con
  /// la anticipación de la clínica) ni los que el servidor rechazó.
  List<Turno> get turnosLibres {
    final t = turnosActuales;
    if (t == null) return const [];

    final prefijo = claveDescartado(t.pacienteId, t.doctorId, null);

    return turnosVigentes(
      t.turnos,
      limite: ahoraConAnticipacion(ahora, reglas),
      descartados: {
        for (final clave in descartados)
          if (clave.startsWith(prefijo))
            ?leerFechaLocal(clave.substring(prefijo.length)),
      },
    );
  }

  EstadoDia get estadoDia {
    if (medico == null) return EstadoDia.sinMedico;
    if (cargandoTurnos) return EstadoDia.cargando;
    if (errorTurnos != null) return EstadoDia.error;
    if (turnosActuales == null) return EstadoDia.cargando;
    if (turnosLibres.isEmpty) return EstadoDia.sinTurnos;

    final f = fecha;
    if (f == null) return EstadoDia.sinFecha;
    if (!tieneTurnos(f)) return EstadoDia.diaSinTurnos;

    return EstadoDia.ok;
  }

  /// Si ese día tiene algún turno libre.
  bool tieneTurnos(DateTime dia) =>
      turnosLibres.any((t) => mismoDia(t.inicio, dia));

  /// Las fichas del día elegido.
  List<Hueco> get huecos {
    final f = fecha;
    if (f == null || estadoDia != EstadoDia.ok) return const [];

    return huecosDelDia(turnosLibres, f, reglas);
  }

  Map<Periodo, List<Hueco>> get grupos => agruparPorPeriodo(huecos);

  int get libres => huecos.length;

  /// El horario elegido, solo mientras siga entre los turnos libres.
  Hueco? get huecoValido {
    final h = hueco;
    if (h == null) return null;

    return huecos.any(h.mismoHorario) ? h : null;
  }

  /// El primer día con turnos libres.
  DateTime? get primerDia => diasConTurnos(turnosLibres).firstOrNull;

  /// Los días de la tira: los que tienen turnos libres.
  List<DateTime> get diasDisponibles {
    final dias = diasConTurnos(turnosLibres);
    final f = fecha;

    // Si el día elegido quedó sin turnos (el de la cita que se reprograma,
    // por ejemplo), se agrega para que siempre se vea marcado.
    if (f != null && dias.isNotEmpty && !dias.any((d) => mismoDia(d, f))) {
      return [...dias, inicioDelDia(f)]..sort();
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
    List<EspecialidadDisponible>? especialidades,
    List<String>? catalogoCiudades,
    List<String>? ciudades,
    bool? cargandoProximos,
    String? errorProximos,
    bool limpiarErrorProximos = false,
    List<Dependiente>? dependientes,
    bool? puedeDependientes,
    String? nombreTitular,
    String? para,
    String? filtroEspecialidad,
    String? filtroCiudad,
    TipoCita? filtroModalidad,
    bool limpiarFiltroModalidad = false,
    String? busqueda,
    MedicoPortal? medico,
    bool limpiarMedico = false,
    TipoCita? tipo,
    DateTime? fecha,
    bool limpiarFecha = false,
    Hueco? hueco,
    bool limpiarHueco = false,
    String? motivo,
    Cita? original,
    bool limpiarOriginal = false,
    TurnosMedico? turnos,
    bool limpiarTurnos = false,
    bool? cargandoTurnos,
    String? errorTurnos,
    bool limpiarErrorTurnos = false,
    Set<String>? descartados,
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
      ciudades: ciudades ?? this.ciudades,
      cargandoProximos: cargandoProximos ?? this.cargandoProximos,
      errorProximos: limpiarErrorProximos
          ? null
          : (errorProximos ?? this.errorProximos),
      dependientes: dependientes ?? this.dependientes,
      puedeDependientes: puedeDependientes ?? this.puedeDependientes,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      para: para ?? this.para,
      filtroEspecialidad: filtroEspecialidad ?? this.filtroEspecialidad,
      filtroCiudad: filtroCiudad ?? this.filtroCiudad,
      filtroModalidad: limpiarFiltroModalidad
          ? null
          : (filtroModalidad ?? this.filtroModalidad),
      busqueda: busqueda ?? this.busqueda,
      medico: limpiarMedico ? null : (medico ?? this.medico),
      tipo: tipo ?? this.tipo,
      fecha: limpiarFecha ? null : (fecha ?? this.fecha),
      hueco: limpiarHueco ? null : (hueco ?? this.hueco),
      motivo: motivo ?? this.motivo,
      original: limpiarOriginal ? null : (original ?? this.original),
      turnos: limpiarTurnos ? null : (turnos ?? this.turnos),
      cargandoTurnos: cargandoTurnos ?? this.cargandoTurnos,
      errorTurnos: limpiarErrorTurnos
          ? null
          : (errorTurnos ?? this.errorTurnos),
      descartados: descartados ?? this.descartados,
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
    ciudades,
    cargandoProximos,
    errorProximos,
    dependientes,
    puedeDependientes,
    nombreTitular,
    para,
    filtroEspecialidad,
    filtroCiudad,
    filtroModalidad,
    busqueda,
    medico,
    tipo,
    fecha,
    hueco,
    motivo,
    original,
    turnos,
    cargandoTurnos,
    errorTurnos,
    descartados,
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
