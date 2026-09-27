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
  ConfigPublica? config,
  CatalogosState? catalogos,
}) {
  return MultiBlocProvider(
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

/// Las rutas públicas de la clínica para [AdaptadorHttpFalso]: la
/// configuración, los catálogos y los documentos legales.
Map<String, Respuesta Function(RequestOptions)> rutasDeLaClinica({
  Map<String, dynamic>? config,
  Map<String, List<Map<String, dynamic>>>? catalogos,
  List<Map<String, dynamic>>? documentosLegales,
}) => {
  'GET /configuracion/publica': (_) =>
      (estado: 200, cuerpo: config ?? configJson()),
  'GET /catalogos/lote': (_) =>
      (estado: 200, cuerpo: catalogos ?? catalogosJson()),
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
