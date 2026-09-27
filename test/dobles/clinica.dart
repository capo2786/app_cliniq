// test/dobles/clinica.dart

/// La configuración pública y los catálogos de una clínica de prueba, y lo
/// que hace falta para montar pantallas con ellos.
///
/// Los valores son los que sembraba el servidor antes de volverse
/// administrables (12 horas, 15 minutos de paso, 20 MB…), así las pruebas
/// que ya existían miden lo mismo. Las que prueban una regla nueva cambian
/// solo el campo que les importa (`configDePrueba(agenda: {...})`).
library;

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/configuracion/config_publica_cubit.dart';
import 'package:app_cliniq/core/configuracion/config_publica_service.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/agendar/dominio/reglas_agendamiento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'adaptador_http.dart';

Map<String, dynamic> _mezclar(
  Map<String, dynamic> base,
  Map<String, dynamic>? cambios,
) => {...base, ...?cambios};

/// `GET /configuracion/publica`, con los cambios pedidos por sección.
Map<String, dynamic> configJson({
  Map<String, dynamic>? clinica,
  Map<String, dynamic>? agenda,
  Map<String, dynamic>? telemedicina,
  Map<String, dynamic>? archivos,
  Map<String, dynamic>? seguridad,
  Map<String, dynamic>? general,
}) => {
  'clinica': _mezclar({
    'nombre': 'Clínica Andina',
    'ruc': '1790000000001',
    'direccion': 'Av. Amazonas N24',
    'telefono': '02 255 0000',
    'correoContacto': 'contacto@andina.ec',
    'sitioWeb': 'https://andina.ec',
    'telefonoEmergencia': '911',
    'eslogan': 'Tu salud, cerca',
    'logo': null,
    'zonaHoraria': 'America/Guayaquil',
    'edadPediatricaMax': 14,
    'edadRepresentanteMenor': 18,
    'edadRepresentanteMayor': 65,
  }, clinica),
  'agenda': _mezclar({
    'horasMinimasCambio': 12,
    'recordatoriosActivos': true,
    'recordatorio24h': true,
    'recordatorio1h': true,
    'recordatorioInicio': false,
    'duracionPresencial': 30,
    'duracionTelemedicina': 20,
    'duracionAsincrona': 15,
    'pasoMinutos': 15,
    'minutosAnticipacionReserva': 15,
    'diasHorizonteReserva': 60,
    'minutosAntesAtender': 15,
    'minutosGraciaRetraso': 10,
    'horaInicioRejilla': '07:00',
    'horaFinRejilla': '21:00',
    'horaInicioTarde': '12:00',
    'horaInicioNoche': '19:00',
  }, agenda),
  'telemedicina': _mezclar({
    'dominio': 'meet.andina.ec',
    'minutosAntes': 15,
    'minutosDespues': 60,
    'minutosAvisoFin': 5,
    'horasRespuesta': 48,
    'diasSeguimiento': 7,
    'maxArchivosConsulta': 30,
  }, telemedicina),
  'archivos': _mezclar({
    'tamanoMaximoMb': 20,
    'tipos': ['application/pdf', 'image/jpeg', 'image/png'],
  }, archivos),
  'seguridad': _mezclar({
    'passwordMinimo': 8,
    'maxIntentos': 5,
    'bloqueoMinutos': 15,
    'otpMinutos': 10,
    'otpDigitos': 6,
    'resetMinutos': 30,
    'inactividadMinutos': 30,
    'reenvioSegundos': 60,
  }, seguridad),
  'general': _mezclar({
    'arcoPlazoDias': 15,
    'encuestasDiasVentana': 30,
    'encuestasPeriodoDias': 90,
    'verificacionMeses': 12,
    'verificacionDiasAviso': 30,
    'soporteHorasSla': {'CRITICA': 4, 'ALTA': 24, 'MEDIA': 72, 'BAJA': 120},
    'soporteHorasAviso': 2,
    'validarCedula': true,
  }, general),
};

ConfigPublica configDePrueba({
  Map<String, dynamic>? clinica,
  Map<String, dynamic>? agenda,
  Map<String, dynamic>? telemedicina,
  Map<String, dynamic>? archivos,
  Map<String, dynamic>? seguridad,
  Map<String, dynamic>? general,
}) => ConfigPublica.desdeJson(
  configJson(
    clinica: clinica,
    agenda: agenda,
    telemedicina: telemedicina,
    archivos: archivos,
    seguridad: seguridad,
    general: general,
  ),
);

/// Las reglas de la rejilla con la configuración de prueba.
ReglasAgendamiento reglasDePrueba({Map<String, dynamic>? agenda}) =>
    ReglasAgendamiento.de(configDePrueba(agenda: agenda).agenda);

Map<String, dynamic> _item(
  String codigo,
  String nombre, {
  String descripcion = '',
  String color = '',
  String icono = '',
  int orden = 0,
  bool esPorDefecto = false,
}) => {
  'codigo': codigo,
  'nombre': nombre,
  'descripcion': descripcion,
  'color': color,
  'icono': icono,
  'orden': orden,
  'esPorDefecto': esPorDefecto,
};

/// `GET /catalogos/lote` con todos los catálogos que pide la aplicación.
Map<String, List<Map<String, dynamic>>> catalogosJson() => {
  Catalogos.especialidad: [
    _item('MEDICINA_GENERAL', 'Medicina General', esPorDefecto: true),
    _item('PEDIATRIA', 'Pediatría', orden: 1),
    _item('DERMATOLOGIA', 'Dermatología', orden: 2),
  ],
  Catalogos.motivoCancelacionPaciente: [
    _item('NO_PUEDO_ASISTIR', 'No puedo asistir'),
    _item('ME_SIENTO_MEJOR', 'Ya me siento mejor', orden: 1),
  ],
  Catalogos.parentescoDependiente: [
    _item('HIJO', 'Hijo/a'),
    _item('MADRE', 'Madre', orden: 1),
    _item('TUTOR', 'Tutor legal', orden: 2),
  ],
  Catalogos.parentesco: [
    _item('MADRE', 'Madre'),
    _item('CONYUGE', 'Cónyuge', orden: 1),
  ],
  Catalogos.modalidadCita: [
    _item(
      'PRESENCIAL',
      'Presencial',
      descripcion: 'En consultorio',
      color: '#5a6e73',
      icono: 'estetoscopio',
    ),
    _item(
      'TELEMEDICINA',
      'Telemedicina',
      descripcion: 'Videollamada en vivo',
      color: '#7a5cc7',
      icono: 'video',
      orden: 1,
    ),
    _item(
      'ASINCRONA',
      'Asíncrona',
      descripcion: 'Revisión de exámenes o mensajes',
      color: '#0f8f8f',
      icono: 'documento',
      orden: 2,
    ),
  ],
  Catalogos.preparacionCita: [
    _item('PRESENCIAL_1', 'Llega 10 minutos antes.'),
    _item('PRESENCIAL_2', 'Trae tu cédula y tus exámenes.', orden: 1),
    _item('TELEMEDICINA_1', 'Conéctate 5 minutos antes.', orden: 2),
    _item('ASINCRONA_1', 'Ten tus exámenes a mano.', orden: 3),
  ],
  Catalogos.ciudad: [
    _item('QUITO', 'Quito'),
    _item('GUAYAQUIL', 'Guayaquil', orden: 1),
    _item('CUENCA', 'Cuenca', orden: 2),
  ],
  Catalogos.sexo: [
    _item('F', 'Femenino'),
    _item('M', 'Masculino', orden: 1),
    _item('O', 'Otro', orden: 2),
  ],
  Catalogos.tipoDocumento: [
    _item('CEDULA', 'Cédula'),
    _item('PASAPORTE', 'Pasaporte', orden: 1),
  ],
  Catalogos.tipoSangre: [
    for (final (i, t) in [
      'O+',
      'O-',
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
    ].indexed)
      _item(t, t, orden: i),
  ],
  Catalogos.estadoCita: [
    _item('PROGRAMADA', 'Programada', color: '#7cc4dc', icono: 'reloj'),
    _item('REAGENDADA', 'Reagendada', color: '#ffc857', icono: 'refresh'),
    _item('ATENDIDA', 'Atendida', color: '#4ade80', icono: 'check-circulo'),
    _item('NO_ASISTIO', 'No asistió', color: '#f87171', icono: 'ban'),
    _item('CANCELADA', 'Cancelada', color: '#9aabaf', icono: 'close'),
  ],
  Catalogos.estadoConsulta: [
    _item(
      'BORRADOR',
      'Borrador',
      descripcion: 'Todavía no la envías: el médico no la ha visto.',
      icono: 'edit',
    ),
    _item(
      'ENVIADA',
      'Enviada',
      descripcion: 'Enviada. El médico todavía no la abre.',
      icono: 'enviar',
    ),
    _item(
      'EN_REVISION',
      'En revisión',
      descripcion: 'El médico está revisando tu consulta.',
      icono: 'search',
    ),
    _item('RESPONDIDA', 'Respondida', icono: 'check-circulo'),
    _item('CERRADA', 'Cerrada', icono: 'candado'),
    _item('CANCELADA', 'Cancelada', icono: 'close'),
  ],
  // Portabilidad desactivada por la clínica (no llega) y Oposición antes
  // que Rectificación: se ofrecen los activos, en su orden.
  Catalogos.tipoArco: [
    _item(
      'ACCESO',
      'Acceso',
      descripcion: 'Saber qué datos tuyos tenemos y para qué los usamos.',
      color: '#0a7fb5',
      icono: 'ojo',
    ),
    _item(
      'OPOSICION',
      'Oposición',
      descripcion: 'Pedir que dejemos de usar tus datos para algo concreto.',
      color: '#c77700',
      icono: 'ban',
      orden: 1,
    ),
    _item(
      'RECTIFICACION',
      'Rectificación',
      descripcion: 'Corregir datos que estén mal o incompletos.',
      color: '#5a6e73',
      icono: 'edit',
      orden: 2,
    ),
    _item(
      'ELIMINACION',
      'Eliminación',
      descripcion: 'Pedir que borremos tus datos cuando ya no hagan falta.',
      color: '#d12e4c',
      icono: 'trash',
      orden: 3,
    ),
  ],
  Catalogos.estadoArco: [
    _item('RECIBIDA', 'Recibida', color: '#0a7fb5', icono: 'correo'),
    _item('EN_PROCESO', 'En proceso', color: '#c77700', icono: 'reloj'),
    _item('RESUELTA', 'Resuelta', color: '#00996a', icono: 'check'),
    _item('RECHAZADA', 'Rechazada', color: '#d12e4c', icono: 'ban'),
  ],
};

CatalogosState catalogosDePrueba([
  Map<String, List<Map<String, dynamic>>>? lote,
]) => CatalogosState(
  listas: interpretarLote(lote ?? catalogosJson()),
  cargados: true,
);

/// Un servicio de configuración que nunca sale a la red. Solo para crear el
/// cubit ya cargado.
ConfigPublicaService servicioDeConfigSinRed() =>
    ConfigPublicaService(Dio(), CacheEnMemoria());

/// Un servicio de catálogos que nunca sale a la red.
CatalogoService servicioDeCatalogosSinRed() =>
    CatalogoService(Dio(), CacheEnMemoria());

/// Pone por encima de [child] la configuración y los catálogos de la
/// clínica, ya cargados, como los tiene la aplicación después del arranque.
Widget conDatosDeLaClinica(
  Widget child, {
  Key? key,
  ConfigPublica? config,
  CatalogosState? catalogos,
}) {
  return MultiBlocProvider(
    key: key,
    providers: [
      BlocProvider(
        create: (_) => ConfigPublicaCubit(
          servicioDeConfigSinRed(),
          inicial: config ?? configDePrueba(),
        ),
      ),
      BlocProvider(
        create: (_) => CatalogosCubit(
          servicioDeCatalogosSinRed(),
          inicial: catalogos ?? catalogosDePrueba(),
        ),
      ),
    ],
    child: child,
  );
}

/// `GET /menus/mi-menu?plataforma=APP` como lo arma la semilla del
/// servidor: grupos con sus enlaces, cada uno con su orden.
List<Map<String, dynamic>> menuJson() => [
  {
    'key': 'general',
    'label': 'General',
    'tipo': 'GRUPO',
    'orden': 0,
    'children': [
      {
        'key': 'inicio',
        'label': 'Inicio',
        'route': '/inicio',
        'icon': 'home',
        'color': '#5fb4d1',
        'tipo': 'LINK',
        'orden': 0,
      },
    ],
  },
  {
    'key': 'atencion',
    'label': 'Atención',
    'tipo': 'GRUPO',
    'orden': 1,
    'children': [
      {
        'key': 'mi-salud',
        'label': 'Mi salud',
        'route': '/mi-salud',
        'icon': 'corazon',
        'color': '#ff6b86',
        'tipo': 'LINK',
        'orden': 5,
      },
      {
        'key': 'mis-citas',
        'label': 'Mis citas',
        'route': '/mis-citas',
        'icon': 'calendario',
        'color': '#5ab8ea',
        'tipo': 'LINK',
        'orden': 2,
      },
      {
        'key': 'agendar-cita',
        'label': 'Agendar cita',
        'route': '/portal/agendar',
        'icon': 'calendario-mas',
        'color': '#3ad5a0',
        'tipo': 'LINK',
        'orden': 3,
      },
      {
        'key': 'mis-dependientes',
        'label': 'Mis dependientes',
        'route': '/portal/dependientes',
        'icon': 'users',
        'color': '#f28a64',
        'tipo': 'LINK',
        'orden': 4,
      },
      {
        'key': 'consultas-en-linea',
        'label': 'Consultas en línea',
        'route': '/portal/consultas',
        'icon': 'estetoscopio',
        'color': '#5fb4d1',
        'tipo': 'LINK',
        'orden': 6,
      },
    ],
  },
  {
    'key': 'ayuda',
    'label': 'Ayuda',
    'tipo': 'GRUPO',
    'orden': 2,
    'children': [
      {
        'key': 'centro-ayuda',
        'label': 'Centro de ayuda',
        'route': '/ayuda',
        'icon': 'info',
        'color': '',
        'tipo': 'LINK',
        'orden': 0,
      },
    ],
  },
];

/// Un sondeo de red que contesta enseguida que hay conexión, para las
/// pantallas sueltas que lo consultan (sin él, el sondeo de verdad dejaría
/// un plazo pendiente al terminar la prueba).
void sondeoConRed() {
  SondeoDeRed.olvidarLaInstancia();
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (pedido, manejador) => manejador.resolve(
          Response<dynamic>(requestOptions: pedido, statusCode: 200, data: ''),
        ),
      ),
    );
  SondeoDeRed(dio);
}

/// Las rutas de la clínica para [AdaptadorHttpFalso]: la configuración, los
/// catálogos y los documentos legales (públicas) y el menú de la
/// aplicación.
Map<String, Respuesta Function(RequestOptions)> rutasDeLaClinica({
  Map<String, dynamic>? config,
  Map<String, List<Map<String, dynamic>>>? catalogos,
  List<Map<String, dynamic>>? documentosLegales,
}) => {
  'GET /configuracion/publica': (_) =>
      (estado: 200, cuerpo: config ?? configJson()),
  'GET /catalogos/lote': (_) =>
      (estado: 200, cuerpo: catalogos ?? catalogosJson()),
  'GET /menus/mi-menu': (_) => (estado: 200, cuerpo: menuJson()),
  'GET /legal/documentos': (_) => (
    estado: 200,
    cuerpo:
        documentosLegales ??
        [
          {
            'clave': 'TERMINOS',
            'slug': 'terminos',
            'version': '1.0',
            'titulo': 'Términos y condiciones de uso',
            'resumen': '',
            'tipos': ['3'],
            'vigenteDesde': '2026-01-01',
          },
        ],
  ),
};
