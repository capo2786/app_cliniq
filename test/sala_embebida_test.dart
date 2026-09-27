// test/sala_embebida_test.dart

import 'dart:convert';

import 'package:app_cliniq/features/citas/data/permisos_de_video.dart';
import 'package:app_cliniq/features/citas/dominio/sala_embebida.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dobles/listas_blancas_jitsi.dart';

/// La sala de Jitsi dentro de la aplicación, sin WebView: la dirección, los
/// ajustes de Jitsi, lo que se decide con cada navegación, permiso y error,
/// y los permisos del teléfono.
void main() {
  /// Lee el fragmento como Jitsi (`parseURLParams`): cada `clave=valor`,
  /// decodificado y leído como JSON.
  Map<String, Object?> comoLoLeeJitsi(String fragmento) => {
    for (final parte in fragmento.split('&'))
      parte.split('=')[0]: jsonDecode(Uri.decodeComponent(parte.split('=')[1])),
  };

  group('Los ajustes de Jitsi', () {
    test('solo claves de las listas blancas de Jitsi', () {
      final ajustes = ajustesDeJitsi(asunto: 'Videoconsulta · Clínica Andina');

      for (final clave in ajustes.keys) {
        final (lista, ruta) = clave.startsWith('config.')
            ? (listaBlancaConfig, clave.substring('config.'.length))
            : clave.startsWith('interfaceConfig.')
            ? (
                listaBlancaInterfaceConfig,
                clave.substring('interfaceConfig.'.length),
              )
            : (const <String>[], clave);

        // `recordingService` habilita `recordingService.enabled`.
        final partes = ruta.split('.');
        final habilitada = [
          for (var i = 1; i <= partes.length; i++)
            partes.sublist(0, i).join('.'),
        ].any(lista.contains);

        expect(habilitada, isTrue, reason: '$clave no está en la lista blanca');
      }
    });

    test('lo pedido que Jitsi no acepta desde la dirección no se manda', () {
      final claves = ajustesDeJitsi(asunto: 'x').keys
          .map((k) => k.substring(k.indexOf('.') + 1))
          .toList();

      for (final fuera in [
        'defaultLanguage',
        'SHOW_JITSI_WATERMARK',
        'SHOW_WATERMARK_FOR_GUESTS',
        'SHOW_BRAND_WATERMARK',
        'MOBILE_APP_PROMO',
        'APP_NAME',
        'enableClosePage',
        'prejoinPageEnabled',
      ]) {
        expect(claves, isNot(contains(fuera)));
        expect(
          [...listaBlancaConfig, ...listaBlancaInterfaceConfig],
          isNot(contains(fuera)),
          reason: 'si Jitsi empieza a aceptarla, se puede mandar',
        );
      }
    });

    test('sin enlaces a la aplicación de Jitsi, sin invitar, grabar ni '
        'transmitir, en español y con la barra justa', () {
      final leido = comoLoLeeJitsi(
        fragmentoDeAjustes(
          ajustesDeJitsi(asunto: 'Videoconsulta · Clínica Andina'),
        ),
      );

      expect(leido, {
        'config.disableDeepLinking': true,
        'config.deeplinking.disabled': true,
        'config.subject': 'Videoconsulta · Clínica Andina',
        'config.localSubject': 'Videoconsulta · Clínica Andina',
        'config.hideConferenceSubject': true,
        'config.defaultLocalDisplayName': 'Yo',
        'config.defaultRemoteDisplayName': 'Participante',
        'config.toolbarButtons': [
          'microphone',
          'camera',
          'chat',
          'raisehand',
          'tileview',
          'select-background',
          'hangup',
          'settings',
        ],
        'config.disableInviteFunctions': true,
        'config.participantsPane.enabled': false,
        'config.disablePolls': true,
        'config.disableReactions': true,
        'config.recordingService.enabled': false,
        'config.recordingService.sharingEnabled': false,
        'config.localRecording.disable': true,
        'config.liveStreamingEnabled': false,
        'config.liveStreaming.enabled': false,
        'config.securityUi.hideLobbyButton': true,
        'config.securityUi.disableLobbyPassword': true,
        'config.enableInsecureRoomNameWarning': false,
        'config.readOnlyName': true,
        'config.disableProfile': true,
        'config.disableThirdPartyRequests': true,
        'config.feedbackPercentage': 0,
        'interfaceConfig.SHOW_POWERED_BY': false,
        'interfaceConfig.PROVIDER_NAME': 'Cliniq',
        'interfaceConfig.NATIVE_APP_NAME': 'Cliniq',
      });
    });

    test('la pantalla previa no se apaga desde la dirección: Jitsi entraría '
        'sin cámara ni micrófono (la apaga el servidor)', () {
      expect(
        ajustesDeJitsi(asunto: 'x').keys.where((k) => k.contains('prejoin')),
        isEmpty,
      );
    });

    test('sin asunto no se manda asunto', () {
      final claves = ajustesDeJitsi(asunto: '   ').keys;

      expect(claves, isNot(contains('config.subject')));
      expect(claves, isNot(contains('config.localSubject')));
      expect(claves, contains('config.hideConferenceSubject'));
    });

    test('el asunto llega entero aunque el nombre traiga comillas '
        'tipográficas, barras o saltos', () {
      final asunto = asuntoParaJitsi(
        'Videoconsulta · Clínica “La Paz”\\\n  & Hijos',
      );
      expect(asunto, 'Videoconsulta · Clínica "La Paz" & Hijos');

      // Jitsi cambia las comillas tipográficas por rectas antes de leer el
      // JSON: con las del asunto ya rectas y escapadas, no se rompe.
      final fragmento = fragmentoDeAjustes({'config.subject': asunto});
      final crudo = Uri.decodeComponent(fragmento.split('=')[1])
          .replaceAll(RegExp('[“”]'), '"');
      expect(jsonDecode(crudo), asunto);
      expect(fragmento, isNot(contains('&H')), reason: 'el & va codificado');

      expect(asuntoParaJitsi('x' * 200), hasLength(120));
    });

    test('la dirección: la sala, el token y el idioma en la consulta, y los '
        'ajustes en el fragmento', () {
      final direccion = Uri.parse(
        direccionDeLaSala(
          dominio: 'meet.andina.ec',
          sala: 'cliniq-abc',
          token: 'aaa.bbb.ccc',
          asunto: 'Videoconsulta · Clínica Andina',
        ),
      );

      expect(direccion.scheme, 'https');
      expect(direccion.host, 'meet.andina.ec');
      expect(direccion.path, '/cliniq-abc');
      expect(direccion.queryParameters, {'jwt': 'aaa.bbb.ccc', 'lang': 'es'});
      expect(
        comoLoLeeJitsi(direccion.fragment)['config.toolbarButtons'],
        botonesDeLaSala,
      );
    });
  });

  group('Las navegaciones de la sala', () {
    DecisionDeNavegacion decidir(String direccion, {bool principal = true}) =>
        decidirNavegacion(
          Uri.parse(direccion),
          dominio: 'meet.andina.ec',
          sala: 'cliniq-abc',
          marcoPrincipal: principal,
        );

    test('la sala se carga, con cualquier consulta o fragmento', () {
      expect(
        decidir('https://meet.andina.ec/cliniq-abc?jwt=t&lang=es#config.x=1'),
        DecisionDeNavegacion.permitir,
      );
      expect(
        decidir('https://MEET.andina.ec/Cliniq-ABC/'),
        DecisionDeNavegacion.permitir,
      );
      expect(
        decidir('https://meet.andina.ec:443/cliniq-abc'),
        DecisionDeNavegacion.permitir,
      );
    });

    test('el mismo servidor fuera de la sala (bienvenida, cierre, otra sala) '
        'es el fin de la videoconsulta', () {
      for (final fuera in [
        'https://meet.andina.ec/',
        'https://meet.andina.ec',
        'https://meet.andina.ec/static/close.html',
        'https://meet.andina.ec/static/close2.html',
        'https://meet.andina.ec/otra-sala',
        'https://meet.andina.ec/cliniq-abc/otra',
      ]) {
        expect(decidir(fuera), DecisionDeNavegacion.terminar, reason: fuera);
      }
    });

    test('todo lo demás se bloquea y se sigue en la sala', () {
      for (final fuera in [
        'https://jitsi.org/',
        'http://jitsi.org',
        'https://meet.jit.si/cliniq-abc',
        'http://meet.andina.ec/cliniq-abc',
        'https://meet.andina.ec:8443/cliniq-abc',
        'https://meet.andina.ec.otro.com/cliniq-abc',
        'intent://meet.andina.ec/cliniq-abc#Intent;scheme=org.jitsi.meet;end',
        'org.jitsi.meet://meet.andina.ec/cliniq-abc',
        'tel:+593222',
        'mailto:a@b.c',
        'about:blank',
        'data:text/html,hola',
        'javascript:alert(1)',
        'https://play.google.com/store/apps/details?id=org.jitsi.meet',
      ]) {
        expect(decidir(fuera), DecisionDeNavegacion.bloquear, reason: fuera);
      }
    });

    test('en un iframe, solo el mismo servidor o un marco vacío', () {
      expect(
        decidir('https://meet.andina.ec/static/x.html', principal: false),
        DecisionDeNavegacion.permitir,
      );
      expect(
        decidir('about:blank', principal: false),
        DecisionDeNavegacion.permitir,
      );
      expect(
        decidir('https://jitsi.org/', principal: false),
        DecisionDeNavegacion.bloquear,
      );
    });

    test('con el puerto en el dominio, ese puerto', () {
      expect(
        decidirNavegacion(
          Uri.parse('https://meet.andina.ec:8443/cliniq-abc'),
          dominio: 'meet.andina.ec:8443',
          sala: 'cliniq-abc',
        ),
        DecisionDeNavegacion.permitir,
      );
    });

    test('la cámara y el micrófono solo para el servidor de video', () {
      expect(
        esOrigenDeLaSala(Uri.parse('https://meet.andina.ec'), 'meet.andina.ec'),
        isTrue,
      );
      expect(
        esOrigenDeLaSala(
          Uri.parse('https://meet.andina.ec/'),
          'meet.andina.ec',
        ),
        isTrue,
      );
      expect(
        esOrigenDeLaSala(Uri.parse('https://jitsi.org'), 'meet.andina.ec'),
        isFalse,
      );
      expect(
        esOrigenDeLaSala(Uri.parse('http://meet.andina.ec'), 'meet.andina.ec'),
        isFalse,
      );
      expect(esOrigenDeLaSala(null, 'meet.andina.ec'), isFalse);
    });

    test('un error es que la sala no cargó solo si es de la página de la '
        'sala y no se canceló', () {
      bool falla(String direccion, {bool? principal, bool cancelado = false}) =>
          esFalloDeCarga(
            Uri.parse(direccion),
            dominio: 'meet.andina.ec',
            sala: 'cliniq-abc',
            marcoPrincipal: principal,
            cancelado: cancelado,
          );

      expect(falla('https://meet.andina.ec/cliniq-abc?jwt=t'), isTrue);
      expect(
        falla('https://meet.andina.ec/cliniq-abc', principal: true),
        isTrue,
      );
      // Un recurso de la página, una navegación bloqueada (iOS la reporta
      // como error) o una carga cancelada no son la sala caída.
      expect(
        falla('https://meet.andina.ec/cliniq-abc', principal: false),
        isFalse,
      );
      expect(falla('https://jitsi.org/'), isFalse);
      expect(falla('https://meet.andina.ec/static/close.html'), isFalse);
      expect(
        falla('https://meet.andina.ec/cliniq-abc', cancelado: true),
        isFalse,
      );
    });
  });

  group('Lo que cuenta la página', () {
    test('entró y terminó; lo demás no es nada', () {
      expect(leerEventoDeSala(['dentro']), EventoDeSala.dentro);
      expect(leerEventoDeSala(['terminada']), EventoDeSala.terminada);
      expect(leerEventoDeSala(['otra cosa']), isNull);
      expect(leerEventoDeSala([]), isNull);
      expect(leerEventoDeSala([42]), isNull);
    });

    test('el guion: solo en el servidor de video, oculta las marcas de '
        'Jitsi, escucha la API y avisa con los mismos nombres', () {
      final guion = guionDeLaSala('Meet.Andina.ec');

      expect(guion, contains('!== "meet.andina.ec"'));
      expect(guion, contains(jsonEncode(estiloDeLaSala)));
      expect(estiloDeLaSala, contains('.watermark'));
      expect(estiloDeLaSala, contains('.poweredby'));
      expect(guion, contains('"$manejadorDeLaSala"'));
      for (final evento in [
        'video-conference-joined',
        'video-ready-to-close',
        'video-conference-left',
        "avisar('dentro')",
        "avisar('terminada')",
        'beforeunload',
        'window.top !== window',
      ]) {
        expect(guion, contains(evento));
      }
      // No toca la cámara ni el micrófono de Jitsi: eso lo decide la sala.
      expect(guion, isNot(contains('mute')));
    });
  });

  group('Los permisos de la cámara y el micrófono', () {
    const si = EstadoDePermiso.concedido;
    const no = EstadoDePermiso.denegado;
    const nunca = EstadoDePermiso.bloqueado;

    test('hacen falta los dos', () {
      expect(resumirPermisos(si, si), ResultadoDePermisos.concedidos);
      expect(resumirPermisos(si, no), ResultadoDePermisos.denegados);
      expect(resumirPermisos(no, si), ResultadoDePermisos.denegados);
      expect(resumirPermisos(no, no), ResultadoDePermisos.denegados);
    });

    test('si uno ya no se puede pedir, solo quedan los ajustes', () {
      expect(resumirPermisos(nunca, si), ResultadoDePermisos.bloqueados);
      expect(resumirPermisos(si, nunca), ResultadoDePermisos.bloqueados);
      expect(resumirPermisos(no, nunca), ResultadoDePermisos.bloqueados);
    });

    test('lo que dice el sistema', () {
      expect(estadoDePermiso(PermissionStatus.granted), si);
      expect(estadoDePermiso(PermissionStatus.limited), si);
      expect(estadoDePermiso(PermissionStatus.denied), no);
      expect(estadoDePermiso(null), no);
      expect(estadoDePermiso(PermissionStatus.permanentlyDenied), nunca);
      expect(estadoDePermiso(PermissionStatus.restricted), nunca);
    });
  });
}
