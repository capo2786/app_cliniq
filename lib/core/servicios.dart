import 'package:flutter/foundation.dart';

import '../features/agendar/data/portal_service.dart';
import '../features/avisos/data/avisos_service.dart';
import '../features/ayuda/data/ayuda_contextual_service.dart';
import '../features/ayuda/data/ayuda_service.dart';
import '../features/auth/data/almacen_de_sesion.dart';
import '../features/auth/data/auth_service.dart';
import '../features/citas/data/citas_service.dart';
import '../features/citas/data/permisos_de_video.dart';
import '../features/citas/data/sala_jitsi.dart';
import '../features/citas/data/videollamada_service.dart';
import '../features/consultas/data/consultas_service.dart';
import '../features/dependientes/data/dependientes_service.dart';
import '../features/encuestas/data/encuestas_service.dart';
import '../features/legal/data/legal_service.dart';
import '../features/privacidad/data/arco_service.dart';
import '../features/mi_salud/data/documentos_pdf_service.dart';
import '../features/mi_salud/data/mi_salud_service.dart';
import '../features/soporte/data/soporte_service.dart';
import 'archivos/archivos_service.dart';
import 'archivos/salida_de_archivos.dart';
import 'archivos/selector_de_archivos.dart';
import 'catalogos/catalogo_service.dart';
import 'configuracion/config_publica_service.dart';
import 'configuracion/logo_clinica_service.dart';
import 'fechas/fecha_local.dart';
import 'integraciones/costuras.dart';
import 'network/api_client.dart';
import 'notificaciones/recordatorios_citas.dart';
import 'presentacion/widgets/lienzo_pdf.dart';
import 'red/estado_de_la_red.dart';
import 'service/biometria_service.dart';
import 'storage/almacen_claves.dart';
import 'storage/cache_local.dart';
import 'storage/credenciales_service.dart';
import 'web/vista_web.dart';
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
   * Lo que depende de un tercero. Los avisos push y los pagos siguen
   * apagados; enchufar el de verdad es cambiar la línea correspondiente:
   * todo lo demás se escribió contra la interfaz.
   */
  static const ServicioPush push = PushApagado();

  static const ServicioPagos pagos = PagosNoDisponibles();

  /// La videoconsulta: la sala de Jitsi de la clínica en una ventana de la
  /// propia aplicación, en un WebView bajo la cabecera de Cliniq, con la
  /// cámara y el micrófono pedidos antes al sistema.
  static final ServicioVideollamada videollamada = VideollamadaEnLaApp(
    VideollamadaService(ApiClient().dio),
    sala: const SalaJitsi(),
    permisos: const PermisosDelSistema(),
  );

  static FabricaDeVistaWeb _vistaWeb = const VistaWebDelSistema();

  /// Las páginas de fuera (un enlace externo del menú, un enlace web de un
  /// artículo de ayuda o de un documento): en un WebView de la propia
  /// aplicación, bajo la cabecera de Cliniq.
  static FabricaDeVistaWeb get vistaWeb => _vistaWeb;

  /// Cambia la vista web por otra. Solo para pruebas: en el anfitrión de
  /// pruebas no hay WebView.
  @visibleForTesting
  static set vistaWebParaPruebas(FabricaDeVistaWeb otra) => _vistaWeb = otra;

  // ── Módulos ────────────────────────────────────────────────────────
  static final AuthService auth = AuthService(ApiClient().dio);

  static final LegalService legal = LegalService(ApiClient().dio, cache);

  /// La configuración pública de la clínica (`/configuracion/publica`).
  static final ConfigPublicaService configuracion = ConfigPublicaService(
    ApiClient().dio,
    cache,
  );

  static LogoClinicaService _logo = LogoClinicaService(ApiClient().dio, cache);

  /// El logotipo de la clínica desde su dirección (`clinica.logo`), con
  /// copia en el teléfono.
  static LogoClinicaService get logoClinica => _logo;

  @visibleForTesting
  static set logoParaPruebas(LogoClinicaService otro) => _logo = otro;

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

  // ── Mi salud, centro de ayuda y soporte ────────────────────────────
  /// La historia clínica que ve el paciente: recetas, órdenes y
  /// certificados de reposo.
  static final MiSaludService miSalud = MiSaludService(ApiClient().dio, cache);

  static DocumentosPdfService _documentosPdf = DocumentosPdfService(
    ApiClient().dio,
  );

  /// Los PDF firmados de recetas y certificados, con su copia en el
  /// teléfono.
  static DocumentosPdfService get documentosPdf => _documentosPdf;

  @visibleForTesting
  static set documentosPdfParaPruebas(DocumentosPdfService otro) =>
      _documentosPdf = otro;

  static SalidaDeArchivos _salida = const SalidaDelSistema();

  /// «Guardar en el teléfono» y «Compartir» un archivo guardado.
  static SalidaDeArchivos get salidaDeArchivos => _salida;

  @visibleForTesting
  static set salidaParaPruebas(SalidaDeArchivos otra) => _salida = otra;

  static PintorDePdf _pintorDePdf = const PintorPdfx();

  /// Cómo se pinta un PDF dentro de la aplicación (`pdfx`).
  static PintorDePdf get pintorDePdf => _pintorDePdf;

  /// En el anfitrión de pruebas no hay lector de PDF del sistema.
  @visibleForTesting
  static set pintorParaPruebas(PintorDePdf otro) => _pintorDePdf = otro;

  /// Los artículos del centro de ayuda.
  static final AyudaService ayuda = AyudaService(ApiClient().dio, cache);

  /// Los textos de los botones de ayuda («?») de quien entró.
  static final AyudaContextualService ayudaContextual = AyudaContextualService(
    ApiClient().dio,
    cache,
  );

  /// Los tickets de soporte de quien entró.
  static final SoporteService soporte = SoporteService(ApiClient().dio, cache);

  static SelectorDeArchivos _selector = SelectorDelSistema();

  /// La cámara, la galería y el selector de archivos del teléfono.
  static SelectorDeArchivos get selectorDeArchivos => _selector;

  /// Cambia los selectores por otros. Solo para pruebas: en el anfitrión de
  /// pruebas no hay cámara ni galería.
  @visibleForTesting
  static set selectorParaPruebas(SelectorDeArchivos otro) => _selector = otro;

  /// Lo que se borra del teléfono al cerrar sesión o al vencer la sesión.
  ///
  /// Las citas, las consultas, los dependientes, los archivos descargados,
  /// los PDF firmados guardados y los recordatorios son de quien estaba
  /// dentro: en un teléfono compartido, la siguiente persona no tiene por qué
  /// verlos ni oírlos. La configuración, los catálogos, los documentos
  /// legales y el logotipo se quedan: son de la clínica.
  static Future<void> limpiarDatosLocales() async {
    await recordatorios.cancelarTodo();
    await cache.vaciarDatosPersonales();
    await archivos.borrarDescargas();
    await documentosPdf.borrarTodo();
    await push.olvidarEsteTelefono();
  }
}
