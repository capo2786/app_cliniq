import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/citas/data/models/cita.dart';
import '../config/entorno.dart';
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

/// Antelación de cada recordatorio.
enum AntelacionRecordatorio {
  unDia(Duration(hours: 24)),
  unaHora(Duration(hours: 1));

  final Duration antes;

  const AntelacionRecordatorio(this.antes);
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

/// Los recordatorios de un conjunto de citas: 24 h y 1 h antes de cada cita
/// pendiente, salvo los que ya pasaron.
///
/// Es aritmética pura —el «ahora» llega como parámetro— para poder probarla
/// sin programar nada en un teléfono.
List<Recordatorio> recordatoriosPara(List<Cita> citas, DateTime ahora) {
  final resultado = <Recordatorio>[];

  for (final cita in citas) {
    if (!cita.pendiente || !cita.inicio.isAfter(ahora)) continue;

    for (final cual in AntelacionRecordatorio.values) {
      final momento = cita.inicio.subtract(cual.antes);

      // Un aviso cuya hora ya pasó no se programa: el sistema lo lanzaría de
      // inmediato y se leería como un error.
      if (!momento.isAfter(ahora)) continue;

      resultado.add(
        Recordatorio(
          id: identificadorDeRecordatorio(cita.id, cual),
          momento: momento,
          titulo: _titulo(cita, cual),
          cuerpo: _cuerpo(cita),
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
  };
}

String _cuerpo(Cita cita) {
  final consejo = switch (cita.tipo) {
    TipoCita.presencial => 'Llega 10 minutos antes con tu cédula y exámenes.',
    TipoCita.telemedicina =>
      'Conéctate 5 minutos antes desde un lugar privado.',
    TipoCita.asincrona => 'Ten tus exámenes a mano.',
  };

  return '${FormatoFecha.hora(cita.inicio)} · ${cita.medicoVisible} · '
      '${cita.tipo.nombre}. $consejo';
}

/// Quien programa los recordatorios. Interfaz para que las pruebas pasen
/// uno que solo anota lo que le pidieron.
abstract interface class ProgramadorDeRecordatorios {
  Future<void> reprogramar(List<Cita> citas, DateTime ahora);

  Future<void> cancelarTodo();
}

/// Los recordatorios locales de las citas.
///
/// Se programan en el propio teléfono con la lista de citas que ya tiene
/// guardada, así que suenan también sin Internet. Se reprograman en cada
/// sincronización —una cita cancelada desde la clínica deja de sonar— y se
/// cancelan todos al cerrar sesión: en un teléfono compartido, la siguiente
/// persona no tiene por qué enterarse de las citas de la anterior.
class RecordatoriosCitas implements ProgramadorDeRecordatorios {
  static const String _canalId = 'cliniq_recordatorios_citas';
  static const String _canalNombre = 'Recordatorios de citas';
  static const String _canalDescripcion =
      'Avisos un día y una hora antes de cada cita.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _inicializado = false;
  tz.Location? _zona;

  RecordatoriosCitas([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// La web no tiene notificaciones locales programadas: ahí todo es un no.
  bool get _soportado => !kIsWeb;

  Future<void> inicializar() async {
    if (_inicializado || !_soportado) return;

    tz_data.initializeTimeZones();
    _zona = tz.getLocation(Entorno.zonaHoraria);
    tz.setLocalLocation(_zona!);

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

  /// Borra lo programado y vuelve a programar desde la lista vigente.
  @override
  Future<void> reprogramar(List<Cita> citas, DateTime ahora) async {
    if (!_soportado) return;

    try {
      await inicializar();
      await cancelarTodo();

      final zona = _zona ?? tz.local;

      for (final recordatorio in recordatoriosPara(citas, ahora)) {
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
