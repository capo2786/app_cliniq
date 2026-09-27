import 'package:flutter/foundation.dart';

import '../features/agendar/data/portal_service.dart';
import '../features/avisos/data/avisos_service.dart';
import '../features/auth/data/almacen_de_sesion.dart';
import '../features/auth/data/auth_service.dart';
import '../features/citas/data/citas_service.dart';
import '../features/citas/data/videollamada_service.dart';
import '../features/consultas/data/consultas_service.dart';
import '../features/dependientes/data/dependientes_service.dart';
import '../features/encuestas/data/encuestas_service.dart';
import '../features/legal/data/legal_service.dart';
import '../features/privacidad/data/arco_service.dart';
import 'archivos/archivos_service.dart';
import 'archivos/selector_de_archivos.dart';
import 'catalogos/catalogo_service.dart';
import 'configuracion/config_publica_service.dart';
import 'fechas/fecha_local.dart';
import 'integraciones/costuras.dart';
import 'network/api_client.dart';
import 'notificaciones/recordatorios_citas.dart';
import 'red/estado_de_la_red.dart';
import 'service/biometria_service.dart';
import 'storage/almacen_claves.dart';
import 'storage/cache_local.dart';
import 'storage/credenciales_service.dart';
import '../features/navegacion/data/menu_service.dart';

/// Raíz de composición: el único lugar donde nacen los servicios.
///
/// Tanto `main.dart` como las pantallas los piden por nombre
/// (`Servicios.portal`) y ninguna pantalla construye el suyo: así cada
/// servicio existe una sola vez, con sus dependencias resueltas, y cambiar
/// cómo se construye uno se hace en esta línea y en ninguna otra.
///
/// Son `static final`, así que se construyen la primera vez que se usan y
/// nunca dos veces. Para una prueba que necesite un doble, el servicio se
/// inyecta por constructor; esta clase es el valor por defecto de
/// producción, no un requisito.
class Servicios {
  const Servicios._();

  // ── Infraestructura ────────────────────────────────────────────────
  static const AlmacenClaves llavero = AlmacenClavesSeguro();

  static CacheLocal _cache = CacheHive();

  /// La copia local de citas, dependientes, el menú, la configuración de la
  /// clínica y sus catálogos.
  static CacheLocal get cache => _cache;

  /// Cambia la caché por otra antes de que nadie la use. Solo para pruebas:
  /// en el anfitrión de pruebas no hay disco para Hive, y abrirla esperaría
  /// su plazo entero antes de rendirse.
  @visibleForTesting
  static set cacheParaPruebas(CacheLocal otra) => _cache = otra;

  static final RelojClinica reloj = RelojClinica();

  static final SondeoDeRed red = SondeoDeRed();

  static final RecordatoriosCitas recordatorios = RecordatoriosCitas();

  static final BiometriaService biometria = BiometriaService();

  static const CredencialesService credenciales = CredencialesService(llavero);

  static const AlmacenDeSesion sesion = AlmacenDeSesion(llavero);

  // ── Costuras de terceros ───────────────────────────────────────────
  /*
   * Lo que depende de un tercero. La videollamada ya está enchufada: abre
   * la sala de Jitsi de la clínica en el navegador. Los avisos push y los
   * pagos siguen apagados; enchufar el de verdad es cambiar la línea
   * correspondiente: todo lo demás se escribió contra la interfaz.
   */
  static const ServicioPush push = PushApagado();

  static final ServicioVideollamada videollamada = VideollamadaEnNavegador(
    VideollamadaService(ApiClient().dio),
  );

  static const ServicioPagos pagos = PagosNoDisponibles();

  // ── Módulos ────────────────────────────────────────────────────────
  static final AuthService auth = AuthService(ApiClient().dio);

  static final LegalService legal = LegalService(ApiClient().dio, cache);

  /// La configuración pública de la clínica (`/configuracion/publica`).
  static final ConfigPublicaService configuracion = ConfigPublicaService(
    ApiClient().dio,
    cache,
  );

  static final CatalogoService catalogos = CatalogoService(
    ApiClient().dio,
    cache,
  );

  static final CitasService citas = CitasService(ApiClient().dio, cache);

  /// El menú de la aplicación de quien entró (`/menus/mi-menu`).
  static final MenuService menu = MenuService(ApiClient().dio, cache);

  /// Los avisos de la campana (`/notificaciones`).
  static final AvisosService avisos = AvisosService(ApiClient().dio, cache);

  /// Mis solicitudes de derechos sobre mis datos (`/portal/arco`).
  static final ArcoService arco = ArcoService(ApiClient().dio, cache);

  /// Las encuestas de las citas atendidas (`/portal/encuestas`).
  static final EncuestasService encuestas = EncuestasService(
    ApiClient().dio,
    cache,
  );

  static final PortalService portal = PortalService(ApiClient().dio);

  static final DependientesService dependientes = DependientesService(
    ApiClient().dio,
    cache,
  );

  static final ConsultasService consultas = ConsultasService(
    ApiClient().dio,
    cache,
  );

  static final ArchivosService archivos = ArchivosService(ApiClient().dio);

  static SelectorDeArchivos _selector = SelectorDelSistema();

  /// La cámara, la galería y el selector de archivos del teléfono.
  static SelectorDeArchivos get selectorDeArchivos => _selector;

  /// Cambia los selectores por otros. Solo para pruebas: en el anfitrión de
  /// pruebas no hay cámara ni galería.
  @visibleForTesting
  static set selectorParaPruebas(SelectorDeArchivos otro) => _selector = otro;

  /// Lo que se borra del teléfono al cerrar sesión o al vencer la sesión.
  ///
  /// Las citas, las consultas, los dependientes, los archivos descargados y
  /// los recordatorios son de quien estaba dentro: en un teléfono compartido,
  /// la siguiente persona no tiene por qué verlos ni oírlos. La configuración,
  /// los catálogos y los documentos legales se quedan: son de la clínica.
  static Future<void> limpiarDatosLocales() async {
    await recordatorios.cancelarTodo();
    await cache.vaciarDatosPersonales();
    await archivos.borrarDescargas();
    await push.olvidarEsteTelefono();
  }
}
