import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/citas/data/models/cita.dart';
import '../../features/citas/dominio/reglas_citas.dart';
import '../../features/citas/presentacion/estilos_cita.dart';
import '../catalogos/catalogos_cubit.dart';
import '../configuracion/config_publica.dart';
import '../fechas/zona_clinica.dart';
import '../formato/fechas.dart';

/// Un recordatorio por programar: cuándo suena y qué dice.
@immutable
class Recordatorio {
  final int id;

  /// Hora local de la clínica en que suena.
  final DateTime momento;

  final String titulo;
  final String cuerpo;
  final String citaId;

  const Recordatorio({
    required this.id,
    required this.momento,
    required this.titulo,
    required this.cuerpo,
    required this.citaId,
  });
}

/// Antelación de cada recordatorio. Cuáles suenan lo decide la clínica en su
/// configuración (`agenda.recordatorio24h`, `recordatorio1h`,
/// `recordatorioInicio`).
enum AntelacionRecordatorio {
  unDia(Duration(hours: 24)),
  unaHora(Duration(hours: 1)),
  alInicio(Duration.zero);

  final Duration antes;

  const AntelacionRecordatorio(this.antes);
}

/// Los recordatorios que la clínica tiene encendidos. Con
/// `agenda.recordatoriosActivos` apagado, ninguno.
List<AntelacionRecordatorio> antelacionesActivas(ReglasAgenda agenda) {
  if (!agenda.recordatoriosActivos) return const [];

  return [
    if (agenda.recordatorio24h) AntelacionRecordatorio.unDia,
    if (agenda.recordatorio1h) AntelacionRecordatorio.unaHora,
    if (agenda.recordatorioInicio) AntelacionRecordatorio.alInicio,
  ];
}

/// Cómo se le cuenta a la persona qué recordatorios va a recibir: «Te
/// recordaremos un día antes y una hora antes.» Sin recordatorios
/// encendidos, `null` (no se promete nada).
String? textoDeRecordatorios(ReglasAgenda agenda) {
  final partes = [
    for (final cual in antelacionesActivas(agenda))
      switch (cual) {
        AntelacionRecordatorio.unDia => 'un día antes',
        AntelacionRecordatorio.unaHora => 'una hora antes',
        AntelacionRecordatorio.alInicio => 'al empezar',
      },
  ];

  if (partes.isEmpty) return null;

  final lista = partes.length == 1
      ? partes.first
      : '${partes.sublist(0, partes.length - 1).join(', ')} y ${partes.last}';

  return 'Te recordaremos $lista.';
}

/// Rango de identificadores reservado para estos recordatorios: cancelar
/// solo estos no borra notificaciones de otra parte de la aplicación.
const int idBaseRecordatorios = 500000;
const int anchoRangoRecordatorios = 100000;

/// Identificador estable de un recordatorio, derivado de la cita y de la
/// antelación. Estable para que reprogramar reemplace y no duplique.
int identificadorDeRecordatorio(String citaId, AntelacionRecordatorio cual) {
  // FNV-1a de 32 bits: el hashCode de un String no es estable entre
  // ejecuciones y aquí hace falta que lo sea.
  var hash = 0x811c9dc5;
  for (final unidad in '$citaId#${cual.name}'.codeUnits) {
    hash ^= unidad;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  return idBaseRecordatorios + hash % anchoRangoRecordatorios;
}

/// Los recordatorios de un conjunto de citas: los que la clínica tiene
/// encendidos, para cada cita pendiente, salvo los que ya pasaron.
///
/// Los textos usan el nombre de la modalidad y los consejos de preparación de
/// los catálogos (`MODALIDAD_CITA`, `PREPARACION_CITA`). Es aritmética pura
/// —el «ahora» llega como parámetro— para poder probarla sin programar nada
/// en un teléfono.
List<Recordatorio> recordatoriosPara(
  List<Cita> citas,
  DateTime ahora, {
  required ReglasAgenda agenda,
  required CatalogosState catalogos,
}) {
  final antelaciones = antelacionesActivas(agenda);
  final resultado = <Recordatorio>[];

  if (antelaciones.isEmpty) return resultado;

  for (final cita in citas) {
    if (!cita.pendiente || !cita.inicio.isAfter(ahora)) continue;

    for (final cual in antelaciones) {
      final momento = cita.inicio.subtract(cual.antes);

      // Un aviso cuya hora ya pasó no se programa: el sistema lo lanzaría de
      // inmediato y se leería como un error.
      if (!momento.isAfter(ahora)) continue;

      resultado.add(
        Recordatorio(
          id: identificadorDeRecordatorio(cita.id, cual),
          momento: momento,
          titulo: _titulo(cita, cual),
          cuerpo: _cuerpo(cita, catalogos),
          citaId: cita.id,
        ),
      );
    }
  }

  return resultado;
}

String _titulo(Cita cita, AntelacionRecordatorio cual) {
  final paraQuien = cita.paraDependiente && cita.pacienteNombre != null
      ? ' de ${cita.pacienteNombre}'
      : '';

  return switch (cual) {
    AntelacionRecordatorio.unDia => 'Mañana hay cita$paraQuien',
    AntelacionRecordatorio.unaHora => 'La cita$paraQuien es en 1 hora',
    AntelacionRecordatorio.alInicio => 'La cita$paraQuien empieza ahora',
  };
}

String _cuerpo(Cita cita, CatalogosState catalogos) {
  final modalidad = estiloDeModalidad(catalogos, cita.tipo).nombre;
  final consejos = consejosPara(catalogos, cita.tipo);

  final datos = [
    FormatoFecha.hora(cita.inicio),
    ?cita.medicoVisible,
    modalidad,
  ].join(' · ');

  return consejos.isEmpty ? datos : '$datos. ${consejos.join(' ')}';
}

/// Quien programa los recordatorios. Interfaz para que las pruebas pasen
/// uno que solo anota lo que le pidieron.
abstract interface class ProgramadorDeRecordatorios {
  /// Borra lo programado y programa exactamente estos. Una lista vacía los
  /// cancela todos (la clínica apagó los recordatorios, o no quedan citas).
  Future<void> programar(List<Recordatorio> recordatorios);

  Future<void> cancelarTodo();
}

/// Los recordatorios locales de las citas.
///
/// Se programan en el propio teléfono con la lista de citas que ya tiene
/// guardada, así que suenan también sin Internet. Se reprograman en cada
/// sincronización —una cita cancelada desde la clínica deja de sonar— y cada
/// vez que cambia la configuración de la clínica, y se cancelan todos al
/// cerrar sesión: en un teléfono compartido, la siguiente persona no tiene
/// por qué enterarse de las citas de la anterior.
///
/// La hora de cada aviso se arma en la zona de la clínica (`ZonaClinica`).
class RecordatoriosCitas implements ProgramadorDeRecordatorios {
  static const String _canalId = 'cliniq_recordatorios_citas';
  static const String _canalNombre = 'Recordatorios de citas';
  static const String _canalDescripcion =
      'Avisos antes de cada cita, los que tenga encendidos la clínica.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _inicializado = false;

  RecordatoriosCitas([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// La web no tiene notificaciones locales programadas: ahí todo es un no.
  bool get _soportado => !kIsWeb;

  Future<void> inicializar() async {
    if (_inicializado || !_soportado) return;

    // El icono pequeño vive en `res/drawable` y es una silueta: Android pinta
    // así los iconos de notificación, y uno a color sale como un cuadrado.
    const android = AndroidInitializationSettings('ic_notificacion');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    _inicializado = true;
  }

  /// Pide el permiso de notificaciones (Android 13+ e iOS).
  Future<bool> solicitarPermiso() async {
    if (!_soportado) return false;

    try {
      await inicializar();

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      // Sin permiso los recordatorios no suenan, pero la aplicación sigue.
      debugPrint('Cliniq · no se pudo pedir el permiso de avisos: $error');
    }

    return false;
  }

  /// Borra lo programado y programa estos.
  @override
  Future<void> programar(List<Recordatorio> recordatorios) async {
    if (!_soportado) return;

    try {
      await inicializar();
      await cancelarTodo();

      // Sin la zona de la clínica no se sabe a qué hora suena cada aviso: se
      // quedan cancelados hasta que llegue la configuración.
      final zona = ZonaClinica.ubicacion;
      if (zona == null) return;

      for (final recordatorio in recordatorios) {
        final m = recordatorio.momento;

        try {
          await _plugin.zonedSchedule(
            id: recordatorio.id,
            title: recordatorio.titulo,
            body: recordatorio.cuerpo,
            // La hora de la cita es hora local de la clínica: se arma en su
            // zona tal cual, sin convertir.
            scheduledDate: tz.TZDateTime(
              zona,
              m.year,
              m.month,
              m.day,
              m.hour,
              m.minute,
            ),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _canalId,
                _canalNombre,
                channelDescription: _canalDescripcion,
                importance: Importance.high,
                priority: Priority.high,
                category: AndroidNotificationCategory.reminder,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            // Inexacto a propósito: no exige el permiso de alarma exacta de
            // Android 12+, y unos minutos de margen no cambian nada aquí.
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: recordatorio.citaId,
          );
        } catch (error) {
          // Si el sistema rechaza uno, los demás se programan igual.
          debugPrint('Cliniq · recordatorio rechazado: $error');
        }
      }
    } catch (error) {
      debugPrint('Cliniq · no se pudieron programar recordatorios: $error');
    }
  }

  /// Cancela todos los recordatorios de citas (y solo esos).
  @override
  Future<void> cancelarTodo() async {
    if (!_soportado) return;

    try {
      await inicializar();

      final pendientes = await _plugin.pendingNotificationRequests();

      for (final pendiente in pendientes) {
        if (pendiente.id >= idBaseRecordatorios &&
            pendiente.id < idBaseRecordatorios + anchoRangoRecordatorios) {
          await _plugin.cancel(id: pendiente.id);
        }
      }
    } catch (error) {
      debugPrint('Cliniq · no se pudieron cancelar recordatorios: $error');
    }
  }
}
