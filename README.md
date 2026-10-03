# Cliniq — Aplicación del paciente

Aplicación móvil de Cliniq para pacientes. Quien tiene cuenta en la clínica
agenda sus citas —y las de las personas a su cargo— sin llamar, las cancela o
reprograma con tiempo, recibe los recordatorios que la clínica tenga
encendidos, y ve sus citas guardadas aunque se quede sin cobertura en la sala
de espera. Además, le escribe a un médico sin cita (**consultas en línea**,
con fotos y documentos, y respuesta en el plazo que fije la clínica) y entra
desde el teléfono a la **videoconsulta** de sus citas de telemedicina.

**Todo lo de negocio lo administra la clínica** desde el panel web: el
nombre, el logotipo y los colores, las reglas de las citas, los plazos, los
textos de los recordatorios, las listas de los formularios, los documentos
legales y el menú. La aplicación no trae ninguno escrito ni listas de
respaldo (ver «Lo que administra la clínica»).

Consume la API `api-cliniq` (gateway NestJS con prefijo `/api` y JWT) y sigue
las mismas reglas que el panel web `dashboard-cliniq`: los horarios que ofrece
la aplicación salen del mismo cálculo, portado línea a línea.

## Requisitos

| Herramienta | Versión |
| --- | --- |
| Flutter | 3.47.5 (fijada en `.fvmrc`) |
| Dart SDK | ^3.13.4 |
| Java | 17 (compilación de Android) |
| Xcode | Solo para compilar iOS |
| Android | 7.0 (API 24) o posterior: el mínimo de Flutter |
| iOS | 15.5 o posterior: ML Kit (el rostro del escáner) pide 15.5; la videoconsulta en WKWebView, 15.1 |

Con [FVM](https://fvm.app) instalado, `fvm use` deja la versión correcta.

## Puesta en marcha

```bash
fvm flutter pub get      # descarga todas las dependencias del pubspec
fvm flutter run
```

`pub get` es lo único que hace falta: las librerías están declaradas en
`pubspec.yaml`, no se instalan a mano una por una.

Tras cambiar dependencias nativas —el paquete de notificaciones, la
biometría— hay que **recompilar**, no basta con recargar en caliente:

```bash
fvm flutter clean
fvm flutter pub get
fvm flutter run
```

## Servicios

La aplicación consume `https://api-cliniq.gcaicedo-proyectos.com/api`. El
panel web, `https://cliniq.gcaicedo-proyectos.com`, no se abre nunca desde la
aplicación: su dirección se enseña, como texto para copiar, al personal que
entra por error, y es el dominio de los enlaces de los correos que abren la
aplicación (ver «Enlaces de los correos»). Las dos se pueden cambiar al
compilar, sin tocar el código:

```bash
flutter build apk --dart-define=API_URL=https://otro-servidor/api --dart-define=WEB_URL=https://otro-panel
```

La configuración vive en `lib/core/config/entorno.dart`. Si cambia
`WEB_URL`, cambia también el dominio de los App Links
(`AndroidManifest.xml`) y de los Universal Links (`Runner.entitlements`).

**Solo HTTPS.** Android 9+ e iOS bloquean el HTTP plano y la aplicación no
lleva excepciones de tráfico en claro. Para probar contra un backend local por
HTTP (en el emulador), hay que agregar una excepción temporal y no subirla.

## Lo que administra la clínica

La regla es del dueño del producto: nada de negocio escrito en la aplicación.
Todo sale de la API, que lo toma de lo que se configura en el panel
(Administración › Configuración, Catálogos, Documentos legales y Menú). Sin
red se usa la última copia descargada; **sin copia, la aplicación lo dice
(«No pudimos cargar los datos de la clínica…») y ofrece «Reintentar»: nunca
arranca con valores inventados.**

| Qué | De dónde | Dónde se usa |
| --- | --- | --- |
| Nombre, eslogan y logotipo de la clínica | `GET /configuracion/publica` → `clinica.nombre`, `eslogan`, `logo` (la dirección absoluta de `GET /configuracion/logo?v=…`, que sale de MinIO; se baja una vez y queda guardada en el teléfono; de un servidor anterior, un data URL; sin él, el logotipo de marca) | Acceso, arranque, inicio, perfil, legales, cerrar sesión, título |
| Colores de la marca | `clinica.colorPrimario`, `colorAcento` (sin ellos, los tokens de siempre) | El tema entero (`PaletaMarca`) |
| Teléfono y correo | `clinica.telefono`, `correoContacto` | Cada «comunícate con la clínica», para tocar (`tel:`, `mailto:`) |
| Número de emergencias | `clinica.telefonoEmergencia` | Consulta nueva |
| Zona horaria | `clinica.zonaHoraria` | El reloj de la clínica, los instantes y los recordatorios |
| Horas para cancelar o reprogramar | `agenda.horasMinimasCambio` | Detalle de la cita, resumen del agendamiento |
| Recordatorios | `agenda.recordatoriosActivos`, `recordatorio24h`, `recordatorio1h`, `recordatorioInicio` | Se programan solo los encendidos; apagados, se cancelan |
| Rejilla de horarios | `agenda.pasoMinutos`, `minutosAnticipacionReserva`, `diasHorizonteReserva`, `horaInicioTarde`, `horaInicioNoche`, `duracionPresencial/Telemedicina/Asincrona` | Agendar |
| Ventana de la sala de video | `telemedicina.minutosAntes`, `minutosDespues` | Botón de la videoconsulta, «Sala abierta» |
| Consultas en línea | `telemedicina.horasRespuesta`, `diasSeguimiento`, `maxArchivosConsulta` | Textos y tope de archivos |
| Mediciones del paciente | `telemedicina.medicionesPacienteActiva`, `escanerCamaraActivo` (apagado por defecto), `escanerSegundos` (20–60) | «Mis signos vitales» y el escáner experimental; sin los campos (un servidor anterior), no se ofrecen |
| Archivos | `archivos.tamanoMaximoMb`, `archivos.tipos` | Selectores y validación antes de subir |
| Seguridad | `seguridad.passwordMinimo`, `bloqueoMinutos`, `otpMinutos`, `resetMinutos`, `reenvioSegundos` | Acceso, código, recuperación, cambiar contraseña, registro («Reenviar enlace») y contraseña nueva |
| Validar la cédula con el módulo 10 | `general.validarCedula` | Dependientes y registro |
| Plazo legal de una solicitud ARCO | `general.arcoPlazoDias` | Mis derechos sobre mis datos |
| Días para responder una encuesta | `general.encuestasDiasVentana` | La encuesta que ya no está disponible |
| Horas de respuesta de soporte | `general.soporteHorasSla` (por severidad), `soporteHorasAviso` | Ticket nuevo |
| Días de gestación | `clinico.diasGestacion` | Mi salud (semanas y fecha probable de parto) |
| Modalidades (nombre, descripción, color, icono) | `GET /catalogos/lote` → `MODALIDAD_CITA` | Citas, agendar |
| Cómo prepararse | `PREPARACION_CITA` (`<MODALIDAD>_<n>`) | Detalle, próxima cita, agendar, recordatorios |
| Estados de citas y consultas | `ESTADO_CITA`, `ESTADO_CONSULTA` | Pastillas y explicaciones |
| Derechos ARCO y sus estados | `TIPO_ARCO` (se ofrecen los activos, en su orden, con su descripción), `ESTADO_ARCO` | Mis derechos sobre mis datos |
| Motivos para cancelar | `MOTIVO_CANCELACION_PACIENTE` | Cancelar una cita |
| Parentescos | `PARENTESCO_DEPENDIENTE` (dependientes), `PARENTESCO` (contacto de emergencia) | Formularios |
| Especialidades y ciudades | `ESPECIALIDAD`, `CIUDAD` | Orden de los filtros de agendar |
| Sexo, documento, tipo de sangre | `SEXO`, `TIPO_DOCUMENTO`, `TIPO_SANGRE` (las etiquetas; los códigos son los de siempre) | Formularios, perfil y Mi salud |
| Soporte | `CATEGORIA_TICKET` (las de la clínica), `SEVERIDAD_TICKET` (las activas, en su orden), `ESTADO_TICKET` | Ticket nuevo, mis tickets y la conversación |
| Artículos de ayuda y guía de usuario | `GET /ayuda` (el servidor ya reemplaza las `{{variables}}` y filtra por los roles de quien entra; el artículo principal de cada guía lleva la clave `guia.<rol>`) | Centro de ayuda, con «Tu guía» primero |
| Textos de los botones de ayuda («?») | `GET /ayuda/contextual` (clave → título, texto y la guía completa; ver «Botones de ayuda») | La barra de cada pantalla y junto a las acciones que no se entienden solas |
| Documentos legales | `GET /legal/documentos` (clave, slug, versión, título), `mis-aceptaciones` y el texto de cada uno, `GET /legal/documentos/:slug` (Markdown con los datos de la clínica ya sustituidos) | Aceptación, perfil y registro; se leen dentro de la aplicación, con copia para leerlos sin red |
| Menú | `GET /menus/mi-menu?plataforma=APP` | La barra de abajo (4 enlaces + «Perfil»), los accesos rápidos y la campana de avisos (si trae `/notificaciones`) |

La configuración, los catálogos y los documentos legales son públicos (se
piden sin token, antes de entrar) y se guardan como datos de la clínica: se
conservan al cerrar sesión. El menú depende de los permisos de quien entró y
se guarda por persona. La configuración y los catálogos se piden al abrir la
aplicación y cada vez que vuelve al frente; si cambian los colores de la
marca, la aplicación se vuelve a pintar, y si cambian las reglas de los
recordatorios, se reprograman.

La lectura de la configuración es estricta con lo que la aplicación usa: un
campo que falta o no tiene la forma esperada descarta la respuesta entera
(se sigue con la copia buena). Los colores de la marca son los únicos
opcionales, porque el contrato dice que sin ellos van los tokens actuales.

**El logotipo** (`LogoClinicaService`, `LogoDeLaClinica`) se pide sin la
sesión a la dirección de `clinica.logo` y se guarda en la caché cifrada como
dato de la clínica (`configuracion:logo`, sobrevive al cierre de sesión). La
dirección lleva la huella corta del archivo (`?v=`): mientras no cambie, no
se vuelve a bajar. Sin red, el último guardado, aunque sea el anterior; sin
ninguno, el de marca. Mientras se baja por primera vez se ve el hueco, no el
de marca un instante. Una dirección que no es absoluta (`https://…`) o un
texto que no es un data URL de imagen se toman como «sin logotipo». El
servidor arma la dirección con `API_URL_PUBLICA`: si queda en `localhost`,
el teléfono no la alcanza y se ve el de marca.

**Lo que sigue en el código, a propósito** (§8 del contrato): los códigos del
sistema y su lógica (estados, modalidades, tipos de documento), las rutas de
la API y las rutas del panel que la aplicación sabe abrir, los límites de
longitud que espejan validadores (500 caracteres del motivo, 4000 de un
mensaje, 6 dígitos del código), la verificación de tipos de archivo por su
contenido, el cálculo de la cédula (módulo 10), los colores que no son de la
marca (fondos, estados, textos) y las URL de despliegue (`API_URL`,
`WEB_URL`). También el rótulo «Portal del paciente», el nombre y el icono
instalados de la aplicación («Cliniq», que el sistema lee del paquete) y el
arranque nativo, que se generan al compilar.

## Dependencias

Todas se resuelven con `pub get`. Se listan aquí para saber qué aporta cada una
antes de tocarla.

### Estado y red

| Paquete | Para qué |
| --- | --- |
| `flutter_bloc`, `bloc` | Gestión de estado de todos los módulos |
| `equatable` | Comparación de estados sin escribir `==` a mano |
| `dio` | Cliente HTTP, con el interceptor del token y del 401 |

### Almacenamiento

| Paquete | Para qué |
| --- | --- |
| `flutter_secure_storage` | Llavero: sesión, perfil guardado, credenciales de la huella y la clave de la caché |
| `hive_ce_flutter` | Caché cifrada: la configuración, los catálogos, los documentos legales y su texto, el menú, las citas, los dependientes, Mi salud y los textos de los botones de ayuda para abrir sin conexión |

### Dispositivo y seguridad

| Paquete | Para qué |
| --- | --- |
| `local_auth` | Entrar con huella o rostro |
| `package_info_plus` | Versión instalada, en el pie del acceso y del perfil |
| `url_launcher` | Solo llamar o escribir a la clínica (`tel:`, `mailto:`, con el marcador y el correo del teléfono). Nada más sale de la aplicación: sin navegador, sin Custom Tabs, sin Safari |
| `app_links` ^7.2.1 | Recibir los enlaces de los correos que abren la aplicación (App Links en Android, Universal Links en iOS) y llevarlos a su pantalla (ver «Enlaces de los correos») |
| `flutter_svg` | Pintar el logotipo de la clínica cuando llega en SVG (`clinica.logo`) |

### Recetas, órdenes y certificados en PDF

| Paquete | Para qué |
| --- | --- |
| `pdfx` ^2.11.0 | Ver el PDF (el firmado o la vista previa) **dentro de la aplicación** (`PdfViewPinch`: páginas una bajo otra, se amplían con los dedos). Usa el lector de PDF del propio sistema (`PdfRenderer` en Android, PDFKit en iOS): nada se abre en otra aplicación ni en el navegador |
| `flutter_file_dialog` ^3.3.3 | «Guardar en el teléfono»: el diálogo del sistema para elegir dónde (en Android, el de documentos; en iOS, el de Archivos). Sin permisos de almacenamiento |
| `share_plus` ^13.3.0 | «Compartir»: la hoja de compartir del sistema, solo si la persona la pide |
| `crypto` | La huella sha256 del PDF: con ella se nombra la copia del teléfono y se comprueba que es el documento firmado |

### Adjuntos de las consultas en línea

| Paquete | Para qué |
| --- | --- |
| `image_picker` | Tomar una foto o elegirla de la galería. La reduce en el propio teléfono (2560 px de lado, calidad 85): de 5–8 MB a menos de uno y medio, sin librerías de imagen en Dart |
| `file_selector` | Elegir un PDF o una imagen guardada (paquete oficial de Flutter, sin permisos) |
| `open_filex` | Abrir un PDF recibido en una consulta o un ticket con el visor del teléfono (los PDF firmados de Mi salud no: esos se ven dentro de la aplicación) |
| `path_provider` | La carpeta temporal privada donde se guarda ese PDF (se borra al cerrar sesión) |

### Videoconsulta

| Paquete | Para qué |
| --- | --- |
| `flutter_inappwebview` ^6.1.5 | La sala de Jitsi de la clínica en un WebView de la propia aplicación: navegación limitada a la sala, la cámara y el micrófono solo para el servidor de video, un guion al cargar y los eventos de la página. También las páginas de fuera (enlaces externos del menú, enlaces web de los artículos y de los documentos), en la pantalla de páginas web. Solo Android e iOS |
| `permission_handler` ^13.0.2 | Pedir la cámara y el micrófono antes de abrir la sala, y abrir los ajustes del teléfono si ya no se puede preguntar |

### Mis signos vitales y escáner experimental

| Paquete | Para qué | Tamaño aproximado |
| --- | --- | --- |
| `camera` ^0.12.1 | Los cuadros de la cámara (YUV420 o NV21 en Android, BGRA en iOS) y el flash como linterna en el modo dedo (`FlashMode.torch`). En Android trae CameraX 1.6 (`camera_android_camerax`); en iOS usa AVFoundation del sistema (`camera_avfoundation`, iOS 13+) | ~1–2 MB en Android (CameraX), ~0,2 MB en iOS |
| `fftea` ^1.5.0+1 | La FFT del procesamiento de la señal (Dart puro, MIT). El filtro Butterworth es propio (biquads de 20 líneas, probados): `iirjdart` es de 2022 y no admite Dart 3 | <50 KB |
| `fl_chart` ^1.2.0 | Las «Tendencias» de «Mis signos vitales» (con la franja de referencia) y las gráficas del detalle de la medición (Dart puro) | ~0,3 MB |
| `google_mlkit_face_detection` ^0.15.1 | El rostro del escáner: la caja, los ángulos y los contornos (~130 puntos) de la cara, con ML Kit de Google, **gratis y en el teléfono**. Modelo empaquetado (`com.google.mlkit:face-detection` en Android; `GoogleMLKit/FaceDetection` en iOS): funciona sin red desde el primer uso | Android: unos 7 MB más por arquitectura (lo que Google indica para el modelo empaquetado). iOS: varios MB más por los pods de ML Kit (`MLKitVision`, `FaceDetection`); hay que medirlo en el primer IPA (`flutter build ipa --analyze-size`) |

**Privacidad con ML Kit.** Las imágenes de la cámara **nunca salen del
teléfono ni se guardan**: cada cuadro pasa al código nativo de ML Kit en el
mismo teléfono y se suelta. Según los términos de Google, ML Kit **puede
enviar a Google métricas anónimas de uso de la librería** (rendimiento,
errores, versión), **nunca imágenes**. Si ML Kit no está o falla dos veces
seguidas, el escáner sigue por el color de la piel dentro del marco, sin
cortar la medición (ver «Escáner experimental»). Lo demás no hace red.

### Fechas y recordatorios

| Paquete | Para qué |
| --- | --- |
| `intl`, `flutter_localizations` | Español en los selectores de fecha del sistema |
| `flutter_local_notifications` ^22.3.0 | Los recordatorios de cada cita que la clínica tenga encendidos |
| `timezone` | La zona de la clínica (`clinica.zonaHoraria`): la hora de la clínica y la de cada aviso |

Son las mismas versiones que usa UCEBell: por debajo de la 22,
`flutter_local_notifications` arrastra un plugin de Windows con un `xml`
incompatible y `pub get` no resuelve.

### Desarrollo

`flutter_lints`, `bloc_test`, `flutter_launcher_icons`, `flutter_native_splash`.

## Configuración nativa

**Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`,
`USE_BIOMETRIC`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED`, más el
receptor que reprograma los recordatorios tras reiniciar el teléfono, y
`CAMERA`, `RECORD_AUDIO` y `MODIFY_AUDIO_SETTINGS` para la videoconsulta.
El identificador es `ec.cliniq.sage.app` y el nombre visible, «Cliniq».

- **Videoconsulta (WebView).** El WebView solo le da la cámara y el
  micrófono a la página si la aplicación ya los tiene: se piden al entrar a
  la sala. `MODIFY_AUDIO_SETTINGS` lo usa WebRTC para el audio de la
  llamada. No hace falta nada más: sin `tools:replace`, sin reglas de R8
  propias (los complementos traen las suyas) y con el `minSdk` de Flutter.
- **Adjuntos.** La cámara se abre con la aplicación de cámara del teléfono
  (intento `IMAGE_CAPTURE`); como la videoconsulta declara `CAMERA`, Android
  exige concederlo antes, e `image_picker` lo pide la primera vez. La galería
  usa el selector de fotos del sistema y los PDF el de documentos, que solo
  entregan lo elegido.
- `open_filex` trae en su manifiesto `READ_EXTERNAL_STORAGE` y
  `READ_MEDIA_IMAGES/VIDEO/AUDIO`, que la aplicación no usa (los PDF van a
  su carpeta privada) y que Google Play restringe: se quitan con
  `tools:node="remove"`.
- `<queries>` declara lo que se abre con otra aplicación del teléfono:
  `tel:` y `mailto:` (llamar o escribir a la clínica), `IMAGE_CAPTURE`
  (cámara) y `application/pdf` (visor). Sin `http`/`https`: la aplicación
  no abre el navegador.
- **App Links.** Un `intent-filter` con `android:autoVerify="true"` para
  `https://cliniq.gcaicedo-proyectos.com/confirmar-correo` y `/restablecer`
  (los enlaces de los correos), y `flutter_deeplinking_enabled` en `false`:
  los enlaces los recibe `app_links` y los enruta la aplicación; con el de
  Flutter encendido, además, Flutter intentaría abrirlos como una ruta con
  nombre. Ver «Enlaces de los correos».
- **PDF firmados.** No piden nada nuevo: `pdfx` usa el `PdfRenderer` del
  sistema, «Guardar en el teléfono» el diálogo de documentos
  (`ACTION_CREATE_DOCUMENT`, sin permiso de almacenamiento) y «Compartir»
  el `FileProvider` que trae `share_plus` en su manifiesto.
  `flutter_file_dialog` pide `minSdk` 24, que es el de Flutter.

- **Escáner experimental.** Usa la misma `CAMERA` con el paquete `camera`:
  la frontal (el rostro, en resolución media y NV21) o, si la clínica lo
  enciende, la trasera con el flash como linterna (`FlashMode.torch`, sin
  permiso aparte). `android.hardware.camera.flash` se declara **no
  obligatorio**: un teléfono sin flash instala igual. El permiso se pide al
  empezar a medir. ML Kit pide `minSdk` 21 y el de Flutter es 24: no hay
  nada que cambiar en Gradle; el modelo va empaquetado (sin
  `com.google.mlkit.vision.DEPENDENCIES` en el manifiesto, que solo hace
  falta para bajar modelos por Google Play).

- `MainActivity` extiende **`FlutterFragmentActivity`**: `local_auth` la
  necesita para mostrar el diálogo de huella. Con la de la plantilla, el
  botón de la huella no hace nada.
- `android/app/build.gradle.kts` activa **core library desugaring** con
  `desugar_jdk_libs:2.1.4` y `multiDexEnabled`. Lo exige
  `flutter_local_notifications`.
- El icono de las notificaciones es `res/drawable/ic_notificacion.xml`, una
  silueta de la cruz: Android pinta así los iconos pequeños y uno a color
  saldría como un cuadrado blanco. `res/raw/keep.xml` evita que el recortador
  de recursos lo borre.
- La firma de publicación lee `android/key.properties`, que no está en el
  repositorio (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Sin
  ese archivo se firma con la clave de depuración.

**iOS** (`ios/Runner/Info.plist`): descripciones de uso de Face ID
(`NSFaceIDUsageDescription`), de la cámara (`NSCameraUsageDescription`: la
videoconsulta, las fotos de los adjuntos y, si la clínica lo activa, el
escáner experimental, cuyas imágenes se procesan en el teléfono y no se
guardan ni se envían), del micrófono
(`NSMicrophoneUsageDescription`: la videoconsulta) y de la fototeca
(`NSPhotoLibraryUsageDescription`), en español, y solo orientación vertical
en teléfono. La plataforma mínima es **iOS 15.5** (`platform :ios, '15.5'` en
`ios/Podfile` e `IPHONEOS_DEPLOYMENT_TARGET` del proyecto): ML Kit
(`google_mlkit_commons` y `google_mlkit_face_detection`) pide 15.5; WebRTC
funciona en WKWebView desde iOS 14.3, y desde iOS 15 la aplicación concede la
cámara y el micrófono a la página sin que esta vuelva a preguntar. ML Kit no
tiene arquitecturas de 32 bits; Flutter ya compila solo `arm64`. El `post_install` del
`Podfile` enciende en `permission_handler` solo `PERMISSION_CAMERA` y
`PERMISSION_MICROPHONE` (sin ellas, iOS los da por negados sin preguntar).
Tras cambiar dependencias, `cd ios && pod install --repo-update` (el
`Podfile.lock` del repositorio está atrasado); `pdfx`, `share_plus` y
`flutter_file_dialog` piden iOS 13 o menos, por debajo del 15.5 del
proyecto, y ninguno necesita una clave nueva en `Info.plist` (la carpeta de
documentos de la aplicación no se comparte con Archivos: no hay
`UIFileSharingEnabled`). El
identificador es `ec.cliniq.sage.app`. El `AppDelegate` se registra como delegado
del centro de notificaciones para que los recordatorios se vean también con
la aplicación abierta.

**Universal Links** (iOS): `ios/Runner/Runner.entitlements` trae
`com.apple.developer.associated-domains` con
`applinks:cliniq.gcaicedo-proyectos.com`, y el proyecto lo usa en Debug,
Release y Profile (`CODE_SIGN_ENTITLEMENTS`). `Info.plist` lleva
`FlutterDeepLinkingEnabled` en `false`, por la misma razón que Android. El
identificador de la aplicación (App ID) necesita la capacidad «Associated
Domains» en la cuenta de Apple; ver «Enlaces de los correos».

## Compilación

```bash
fvm flutter build appbundle --release   # Google Play
fvm flutter build apk --release         # APK directo
fvm flutter build ipa --release         # App Store
```

## Convenciones de código

Son las de UCEBell, con los colores de Cliniq:

- **Colores, degradados, espaciados y radios** salen de
  `lib/core/tema/tokens.dart` (`AppColors`, `AppGradientes`, `AppEspaciado`,
  `AppRadio`). Ningún `Color(0xFF...)` suelto en una pantalla: si falta un
  color, se agrega al sistema con nombre.
- **Las pantallas oscuras van sobre `FondoDegradado`**
  (`lib/core/presentacion/widgets/fondo_app.dart`) y abren con una
  `TarjetaEncabezado` sobre `AppGradientes.encabezado`, seguida de etiquetas
  de sección en mayúsculas (`EtiquetaSeccion`). Las tarjetas son
  semitransparentes (`TarjetaTranslucida`), no bloques opacos.
- **La acción principal** de cada pantalla es un `BotonPrincipal`: el
  degradado terracota con su propia sombra de color. Una sola por pantalla.
- **Cerrar sesión** siempre por `BotonCerrarSesion` /
  `confirmarCierreDeSesion` (`lib/core/presentacion/widgets/cerrar_sesion.dart`),
  en la barra de todas las pantallas de contenido. Siempre pregunta antes.
- **HTTP** siempre por `ApiClient().dio`. Es un singleton: el token y el aviso
  de sesión vencida viven ahí, y un `Dio` aparte no llevaría ninguno de los
  dos.
- **Servicios compartidos** salen de `lib/core/servicios.dart`
  (`Servicios.portal`, `Servicios.citas`…), el único lugar donde se
  construyen. Las pantallas no instancian servicios; los constructores con
  parámetros existen para inyectar dobles en las pruebas.
- **Mensajes de error HTTP** con `mensajeDeError` de
  `lib/core/network/errores.dart`. La API responde `{status, message}` y
  `message` puede ser texto o lista; el acceso atiende primero sus casos
  (401 y 423, en `errores_de_acceso.dart`) y delega el resto.
- **Las fechas de la API** pasan siempre por `lib/core/fechas/fecha_local.dart`
  (ver abajo). Un `DateTime.parse` suelto sobre una fecha de la API es un
  error.
- **Nada de negocio escrito.** Una regla, un número, una lista o un texto
  que la clínica pueda querer cambiar se lee de la configuración o de un
  catálogo: en una pantalla, `context.config` y `context.catalogos`
  (`lib/core/configuracion/en_contexto.dart`); en un bloc, por su
  constructor; en una regla pura, por parámetro. Sin datos no se inventan:
  se dice y se ofrece «Reintentar».
- **El estado vive en blocs**; las páginas pintan y despachan eventos. Los
  blocs que comparten las pestañas (configuración, catálogos, sesión, citas,
  consultas, dependientes y menú) se crean en `main.dart`; una pantalla que se abre por navegación
  (agendar, perfil) crea el suyo para cargar datos frescos en cada visita.
- **El relleno inferior de una lista** sale de `context.margenDeScroll(...)`
  (`lib/core/presentacion/margenes.dart`), que descuenta la barra de
  navegación de Android.
- Los módulos siguen la estructura `features/<modulo>/{data,providers,presentacion}`,
  y las reglas puras de un módulo van en `dominio/`.

### Los colores

Los de la marca (primario, acento y sus tonos) salen de la configuración de
la clínica (`PaletaMarca`, `lib/core/tema/paleta_marca.dart`) y por eso son
getters, no constantes; los valores de la tabla son los de siempre, los que
se usan si la clínica no configuró los suyos. Los demás sí son constantes.

| Token | Valor | Papel |
| --- | --- | --- |
| `AppColors.primario` | `#5A6E73` | Gris azulado de la marca: el anillo del logotipo |
| `AppColors.primarioClaro` | `#9DB3B8` | La marca aclarada para iconos sobre fondo oscuro |
| `AppColors.acento` | `#D16F4B` | Terracota: la cruz y la acción principal |
| `AppColors.acentoClaro` | `#E8956F` | Final del degradado del botón y anillo de foco |
| `AppColors.fondo` | `#0F171A` | Fondo: el gris azulado casi negro |
| `AppColors.fondoProfundo` | `#0B1113` | Inicio y arranque |
| `AppColors.superficie` | `#162022` | Barras, hojas inferiores y diálogos |
| `AppColors.exito` / `alerta` / `peligro` | `#4ADE80` / `#FBBF24` / `#EF4444` | Los mismos papeles que en UCEBell |

`AppGradientes.encabezado` baja de `#62797F` a `#2B393C`;
`AppGradientes.bienvenida`, el saludo del inicio, sube de `#465A5F` por el
gris azulado de la marca hasta el terracota; `AppGradientes.accion` va de
`#D16F4B` a `#E8956F`.

## Estructura

```
lib/
  main.dart                   arranque protegido, blocs compartidos y la puerta de entrada
  core/
    arranque/                 que un fallo al arrancar se vea
    catalogos/                los catálogos de la clínica, completos y sin valores de partida
    config/entorno.dart       API_URL, WEB_URL (el dominio de los enlaces de los correos)
    configuracion/            la configuración pública de la clínica: modelo, servicio, cubit
    archivos/                 adjuntos: ArchivoMeta, validación antes de subir, selectores y descargas
    fechas/fecha_local.dart   la hora «congelada» de la API y el reloj de la clínica
    fechas/zona_clinica.dart  la zona horaria de la configuración
    fechas/instante.dart      los instantes reales (consultas, mensajes, archivos) en la hora de la clínica
    formato/fechas.dart       cómo se enseñan las fechas
    integraciones/costuras.dart  push y pagos: interfaces, todavía apagadas
    network/                  ApiClient, interceptores, mensajeDeError
    notificaciones/           recordatorios locales de citas
    presentacion/             márgenes, avisos, enlaces, el observador de rutas, los widgets base
                              (también TextoMarkdown, para los textos del servidor),
                              el contacto y el logotipo de la clínica, iconos y colores del servidor
    red/                      el sondeo de la red y el cartel de sin conexión
    storage/                  llavero, credenciales y caché cifrada
    tema/                     tokens, la paleta de la marca y el tema de Material
    web/                      las páginas de fuera: qué se abre y qué se bloquea, y el WebView
    servicios.dart            la raíz de composición
  features/
    arranque/                 la espera de los datos de la clínica y de la sesión
    auth/                     acceso, segundo factor, recuperación, sesión, registro de
                              pacientes, confirmar el correo y la contraseña nueva
    legal/                    documentos legales de la API, su aceptación y su lectura nativa
    navegacion/               el menú del servidor, el enrutador de las rutas del sistema,
                              las pantallas que abre cada una, «Muy pronto» y los
                              enlaces de los correos que abren la aplicación
    inicio/                   el inicio y la barra de pestañas
    avisos/                   la campana de la cabecera y la lista de avisos
    privacidad/               mis derechos sobre mis datos (solicitudes ARCO)
    encuestas/                la encuesta de una cita atendida y el aviso del inicio
    citas/                    mis citas, detalle, cancelar, las horas para cambiar y la videoconsulta
    consultas/                consultas en línea: lista, consulta nueva paso a paso y detalle con la conversación
    agendar/                  el agendamiento paso a paso y el cálculo de horarios
    dependientes/             personas a cargo, con la validación de cédula
    perfil/                   datos personales y clínicos, seguridad, documentos
    mi_salud/                 la historia clínica que ve el paciente: recetas (en sus dos
                              partes), órdenes, certificados de reposo, la firma electrónica
                              y el visor de PDF
    mediciones/               «Mis signos vitales» (lista, evolución, Registrar, la cola sin
                              red) y el escáner experimental: escaner/ (cámara, extracción,
                              motor, cubit y pasos) y dominio/procesamiento_ppg.dart con
                              dominio/ppg/ (el cálculo puro de la FC, la FR y la calidad)
    ayuda/                    centro de ayuda («Tu guía» primero, búsqueda, categorías y
                              artículos en Markdown nativo) y los botones de ayuda («?»)
    soporte/                  mis tickets, ticket nuevo y la conversación con soporte
test/                         pruebas (ver abajo)
tool/generar_iconos_test.dart genera los PNG del icono y del arranque
```

## Pantallas

1. **Arranque.** Primero, los datos de la clínica: con una copia guardada se
   pasa enseguida; la primera vez se espera la respuesta y, sin red, se dice
   con «Reintentar». Mientras se restaura la sesión guardada se ve el
   logotipo sobre el mismo fondo del arranque nativo. La sesión se confirma con
   `GET /auth/me` (con plazo corto): la respuesta trae los documentos legales
   pendientes, y si la clínica publicó una versión nueva hay que pasar por la
   aceptación antes que por el inicio. Sin red se entra igual con el perfil
   guardado.
2. **Acceso.** Ver «Pantalla de acceso».
3. **Aceptación legal.** Si `legalPendientes` no está vacío, bloquea todo lo
   demás. Cada documento tiene su botón «Leer», que abre su texto dentro de
   la aplicación (ver «Documentos legales»), y su casilla; «Aceptar y continuar»
   se enciende cuando están todas marcadas, manda `POST /legal/aceptar` y
   relee `/auth/me`. La otra salida es cerrar sesión.
4. **Inicio.** El saludo sobre el degradado de bienvenida; «Tu próxima cita»
   con la hoja de calendario, la hora, el médico, la modalidad, la cuenta
   regresiva y cómo prepararse según la modalidad (los consejos de
   `PREPARACION_CITA`) —el día de una cita de telemedicina, con el botón de
   la videoconsulta—, y los accesos rápidos: los enlaces del menú que no
   caben en la barra; «Consultas en línea», si está entre ellos, a lo ancho y
   con las respuestas del médico por leer.
5. **Citas.** Próximas e Historial; las de un dependiente llevan «Para
   <nombre>». El detalle se abre en una hoja inferior con «Reprogramar» (el
   agendamiento en modo reprogramar, con el mismo médico y la misma
   modalidad) y «Cancelar cita» (motivo de `MOTIVO_CANCELACION_PACIENTE` y
   detalle opcional). Con menos de las horas de la clínica por delante, las
   dos acciones desaparecen y se explica por qué, con su teléfono y su
   correo. Las de telemedicina traen «Entrar a la videoconsulta»
   (ver «Videoconsulta»).
6. **Agendar.** Un paso por pantalla: para quién (con «Agregar dependiente»),
   filtros de especialidad, ciudad y modalidad, el médico (modalidades,
   resumen del horario y primera fecha libre), la modalidad (solo las que
   ofrece), el día en una tira que empieza en el primer día con atención y
   las horas agrupadas en mañana, tarde y noche, el motivo (obligatorio, hasta
   500 caracteres), el resumen y la confirmación. Si al confirmar el servidor
   rechaza —alguien tomó la hora—, se vuelve a pedir lo ocupado y, si esa
   hora ya no está libre, se vuelve a elegir. El botón «atrás» vuelve un paso,
   no tira lo elegido.
7. **Dependientes.** Lista, alta y edición con validación: nombre, parentesco
   (`PARENTESCO_DEPENDIENTE`), fecha de nacimiento (no futura), documento
   (cédula —con módulo 10 si la clínica lo pide— o pasaporte), sexo, tipo de
   sangre (con las etiquetas de sus catálogos) y datos clínicos. Quitar pregunta
   antes; con citas pendientes el servidor lo impide y la aplicación lo dice.
8. **Perfil.** Datos personales y clínicos, con edición de lo que la API deja
   cambiar a uno mismo (el correo y la cédula se cambian en la clínica);
   cambiar contraseña, verificación en dos pasos, acceso con huella,
   documentos aceptados y los documentos legales vigentes de la clínica (los
   dos se leen dentro de la aplicación), cerrar sesión y la versión.
9. **Consultas en línea.** Ver «Consultas en línea».
10. **Recordatorios.** Ver «Recordatorios».
11. **Sin conexión.** Ver «Sin conexión».

La barra de abajo la arma el menú del servidor (`GET
/menus/mi-menu?plataforma=APP`): los cuatro primeros enlaces por su orden,
con el nombre, el icono y el color del administrador, más **Perfil**, que
siempre está; el resto va a los accesos rápidos del inicio. Agendar va
destacado y no cambia de pestaña: abre el agendamiento encima. El menú se
guarda para abrir sin red; sin copia, un aviso con «Reintentar».

**Ningún enlace saca a la persona de la aplicación.** El enrutador
(`lib/features/navegacion/dominio/destinos.dart`, `rutasDelSistema`) entiende
las rutas del sistema, también con parámetros, y lo usan el menú, los avisos
de la campana y los enlaces de los textos (`abrirRuta`, en
`navegacion/presentacion/enrutador.dart`):

| Ruta | Pantalla |
| --- | --- |
| `/inicio`, `/mis-citas`, `/portal/dependientes`, `/portal/consultas`, `/perfil` | Su pestaña (o encima, si no está en la barra) |
| `/portal/agendar` | Agendar, encima |
| `/portal/consultas/:id` | El detalle de la consulta |
| `/portal/videoconsulta/:citaId` | La cita, con la videoconsulta abierta encima si la sala está abierta |
| `/notificaciones` | Los avisos de la campana |
| `/portal/arco`, `/privacidad/solicitudes` | Mis derechos sobre mis datos |
| `/portal/encuesta/:citaId` | La encuesta de la cita |
| `/legal/:slug` | El documento legal |
| `/mi-salud` | Mi salud (también desde los avisos «Tu receta está lista» y «Tu certificado de reposo está listo») |
| `/portal/mediciones` | Mis signos vitales |
| `/ayuda`, `/soporte`, `/soporte/tickets/:id` | El centro de ayuda, soporte y el ticket (dentro de un artículo, `/ayuda?articulo=<id>` abre ese artículo) |

La consulta y el fragmento de la ruta se ignoran. Una ruta del menú que la
aplicación no sabe abrir no se enseña (ni en la barra ni en los accesos); un
enlace externo del menú (una dirección que puso el administrador) se abre en
la pantalla de páginas web de la aplicación (ver «Páginas de fuera»); `tel:`
y `mailto:`, con el marcador y el correo del teléfono. Las pantallas de cada destino se arman en un solo lugar,
`navegacion/presentacion/pantallas_nativas.dart` (`pantallaNativa`): ahí se
conectan las que falten.

## Avisos (la campana)

La campana de la cabecera es administrable: aparece solo si el menú de la
aplicación de la persona trae el enlace a `/notificaciones` (el servidor lo
siembra como «Avisos»). Ese enlace no va en la barra ni en los accesos: es la
campana, con su nombre como título y un número con los avisos sin leer
(`GET /notificaciones/no-leidas/contador`; hasta «99+»). Está en la cabecera
de cada pestaña.

- **Cuándo pregunta.** Al entrar, al volver a primer plano y cada minuto con
  la aplicación abierta (el mismo intervalo de la campana del panel); en
  segundo plano no pregunta. Si el servidor no responde, se queda el último
  número. `CampanaCubit` (`features/avisos/providers`) nace en `main.dart` y
  el tablero la enciende o la apaga según el menú.
- **La lista** (`GET /notificaciones?limite=20`, «Ver avisos anteriores» con
  `antesDe`): icono según el tipo, fecha relativa en la hora de la clínica
  («hace 5 min», «ayer», «28 sep»), los sin leer resaltados, «Marcar todas
  como leídas» (`PATCH /notificaciones/leer-todas`) y deslizar para borrar
  (`DELETE /notificaciones/:id`). Los cambios se ven al instante; si el
  servidor dice que no, se deshacen. Vacía, «Todo al día»; sin red, la última
  copia (`avisos:<uid>`, se borra al cerrar sesión); sin copia, el error con
  «Reintentar».
- **Al tocar un aviso** queda leído (`PATCH /notificaciones/:id/leida`) y su
  `enlace` se abre con el enrutador: una pestaña cierra la lista y la
  enseña; lo demás se abre encima. Si el enlace no es del paciente
  (`/admin/...`), se queda en la lista y lo dice. Los de una receta o un
  certificado firmados («Tu receta está lista», «Tu certificado de reposo
  está listo») llevan a `/mi-salud` y abren Mi salud.

## Mis derechos sobre mis datos (ARCO)

En el perfil, siempre (no es un elemento del menú: es un derecho legal),
«Mis derechos sobre mis datos» abre la lista de solicitudes
(`GET /portal/arco`): tipo y estado con los nombres, colores e iconos de
`TIPO_ARCO` y `ESTADO_ARCO`, cuándo se envió, el plazo en la hora de la
clínica («Respuesta a más tardar el 12 de octubre (en 15 días)», o que ya
venció, con el camino a soporte), la respuesta de la clínica y el historial.
Las abiertas van primero. El encabezado explica el plazo legal con
`general.arcoPlazoDias`. Sin red, la última copia (`arco:<uid>`, se borra al
cerrar sesión); sin copia, el error con «Reintentar».

«Nueva solicitud» (`POST /portal/arco {tipo, detalle}`) ofrece los derechos
activos de `TIPO_ARCO`, en su orden y con su descripción, y el detalle con
los mismos límites que el panel y el API (de 10 a 2000 caracteres, sin los
espacios de los extremos). El botón va en la `BarraDeAccion`, sobre el
teclado. Si el servidor no la acepta, se enseña su mensaje y el formulario
queda como estaba.

## Encuestas

Las citas atendidas de los últimos `general.encuestasDiasVentana` días sin
encuesta (`GET /portal/encuestas/pendientes`; el servidor decide cuáles) se
leen como citas, igual que en el panel. Si hay, el inicio lo avisa bajo la
próxima cita («¿Cómo te fue en tu consulta?»), y el aviso abre la encuesta
de la más reciente. Se piden al entrar, al volver a la aplicación y al
deslizar el inicio; sin red, la última copia (`encuestas:<uid>`, se borra al
cerrar sesión).

La pantalla (`/portal/encuesta/:citaId`) es la del panel: la cita (médico,
especialidad, día, modalidad del catálogo y para quién), de 1 a 5 estrellas,
cuánto recomendaría al médico de 0 a 10 y un comentario opcional de hasta
1000 caracteres (`POST /portal/encuestas`). Sin contestar las dos preguntas
dice qué falta; enviada, «¡Gracias por tu opinión!» y «Responder la
siguiente»; si ya estaba respondida (409), lo dice; si la cita ya no está
entre las pendientes, «ya no está disponible» con los días de la
configuración. Sin la lista (sin red), se responde igual. El botón va en la
`BarraDeAccion`, sobre el teclado.

## Documentos legales

El texto de cada documento llega de `GET /legal/documentos/:slug` (pública)
en Markdown, con las variables de la clínica ya sustituidas por el servidor,
y se pinta con `TextoMarkdown` (`core/presentacion/widgets/texto_markdown.dart`):
entiende lo mismo que el panel (`core/markdown.ts`) —párrafos, títulos `#` a
`###`, **negrita**, listas y enlaces `http`, `https`, `mailto` o rutas
internas— y nada más, así que no hay HTML que sanear. Un enlace interno
(`/legal/privacidad`) abre su pantalla con el enrutador; uno web, la
pantalla de páginas web de la aplicación. Queda una copia por documento
(`legal:texto:<slug>`, de la clínica: sobrevive al cierre de sesión) para
leerlo sin red; un 404 dice «Documento no encontrado» y no enseña la copia
vieja. Lo usan la aceptación de documentos, el perfil y el registro de
pacientes.

## Pantalla de acceso

Replica la de UCEBell: el logotipo y el nombre de la clínica —sin logotipo
propio, el de marca, el mismo del icono—, su eslogan, la tarjeta
de **vidrio** que desenfoca el fondo, el contenido que **sube al abrir**, cada
campo con su icono en una pastilla y el **anillo de foco terracota**, y un
solo botón con el degradado de la marca. Al pie, la **versión instalada**.

- **«¿Olvidaste tu contraseña?»** pide el enlace con
  `POST /auth/password/olvido`. La API contesta siempre lo mismo, exista o no
  el correo. El enlace del correo, abierto en el teléfono, abre la
  aplicación en la pantalla de la contraseña nueva (ver «Enlaces de los
  correos»); en una computadora, el panel.
- **Verificación en dos pasos.** Si la cuenta la tiene, la API contesta
  `{requiere2fa, desafio, destino}` y la misma tarjeta pasa al paso del
  código de seis dígitos (`POST /auth/login/2fa`).
- **Cuenta bloqueada.** Varios intentos fallidos la cierran unos minutos
  (HTTP 423; cuántos, `seguridad.bloqueoMinutos`). Se explica con el texto
  del servidor y se ofrece recuperar la contraseña.
- **Sesión vencida.** La API no tiene token de renovación. Un 401 con la
  sesión abierta borra la sesión y lleva al acceso con el aviso «Tu sesión
  venció». Un 401 en las rutas del acceso no es eso: son credenciales o un
  código equivocados.
- **Crear cuenta.** El pie dice «¿No tienes cuenta? Crea tu cuenta» y abre
  el registro de la aplicación, una pantalla propia con su diseño (ver
  «Registro de pacientes»). Al volver con la cuenta creada, el correo queda
  escrito en el acceso.
- **Correo sin confirmar.** Una cuenta del autorregistro que todavía no abrió
  su enlace recibe 403 con `codigo: CORREO_NO_VERIFICADO`: la tarjeta dice
  «Confirma tu correo para entrar» y ofrece «Reenviar el enlace»
  (`POST /auth/registro/reenviar { email }`), que enseña siempre la misma
  respuesta neutral —no revela si la cuenta existe— y se apaga
  `seguridad.reenvioSegundos` entre pedidos.
- **Solo pacientes.** Una cuenta sin `portal.mis_citas` en sus permisos (el
  personal de la clínica, también el administrador: su comodín `*` no abre
  el portal) no entra: se descarta el token sin guardar sesión ni
  credenciales y se explica «Esta aplicación es para pacientes. El personal
  de la clínica usa el panel web desde una computadora, en esta dirección:»,
  con la dirección del panel (`WEB_URL`) como texto seleccionable y un botón
  para copiarla: no es un enlace y la aplicación no la abre. Lo mismo al
  restaurar una sesión guardada.

### Entrar con la huella

Quien ya entró en este teléfono ve su correo y un botón para **entrar con
huella o rostro**; el formulario queda debajo, y «Entrar con otra cuenta»
olvida lo guardado. Las credenciales se guardan en el llavero **solo después
de un acceso correcto** (y del código, si hay segundo factor) y la contraseña
**nunca se escribe sola** en el formulario: sale del llavero únicamente
después de la huella. En UCEBell se precarga porque allí se entra sin
Internet; aquí no hay acceso sin conexión y precargarla solo serviría para
que cualquiera con el teléfono en la mano entrara tocando un botón.

La huella se apaga desde el perfil, y apagarla borra la contraseña guardada.
Las reglas viven en `lib/features/auth/data/acceso.dart`.

## Registro de pacientes

«Crea tu cuenta», en el acceso, abre `RegistroPage`
(`features/auth/presentacion/registro_page.dart`): el registro del panel web
(`/registro`) con el diseño de la aplicación. Pide lo mismo, con las mismas
reglas y los mismos mensajes que el panel (`core/validadores.ts`,
`ui/fortaleza`) y que el API (`validarRegistro` en `auth-ms`); las reglas
viven en `features/auth/dominio/registro.dart` y son puras.

| Campo | Regla |
| --- | --- |
| Nombres y apellidos * | De 3 a 120 caracteres; se envía sin espacios de más |
| Correo electrónico * | Con forma de correo (y dominio con punto, como exige el API), hasta 120; se envía en minúsculas |
| Teléfono | Opcional; de 7 a 15 dígitos, espacios, guiones y un «+» inicial |
| Documento * | El tipo, de `TIPO_DOCUMENTO` (cédula por defecto); el número, obligatorio: la cédula con el módulo 10 si la clínica lo pide (`general.validarCedula`; si no, diez dígitos), el pasaporte de 5 a 20 letras o números; se envía en mayúsculas |
| Fecha de nacimiento * | Con el selector del sistema; no futura (el selector no ofrece días después de hoy, en la hora de la clínica) |
| Sexo | Opcional, de `SEXO`, con «Prefiero no decirlo» |
| Contraseña * | El mínimo de la clínica (`seguridad.passwordMinimo`) y el máximo del API (128). Debajo, la barra de fortaleza del panel con sus pistas («Débil: usa al menos N caracteres», «Aceptable: combina mayúsculas, números o símbolos», «Buena», «Muy buena») |
| Repite la contraseña * | Igual a la primera |
| Documentos legales * | Los que el API da por aceptados al crear la cuenta: **Términos y condiciones** y **Política de privacidad** (claves `TERMINOS` y `PRIVACIDAD`, del sistema, como en el panel), con el título, la versión y el slug de `GET /legal/documentos`, si aplican a pacientes. Cada uno con «Leer» (el lector de la aplicación, `/legal/:slug` por el enrutador) y su casilla |

Debajo de las casillas se listan, para leerlos, los demás documentos
vigentes de los pacientes (aviso legal, uso aceptable, consentimiento de
telemedicina…): el registro no los acepta —el API solo registra términos y
privacidad con `aceptaTerminos: true`, como lo manda el panel—, así que se
aceptan al entrar por primera vez, en la pantalla de aceptación. Sin la
lista de documentos (sin red y sin copia) se dice con «Reintentar» y no se
puede enviar: no se acepta lo que no se pudo leer. Si la clínica no tuviera
vigente ninguno de los dos, queda una sola casilla sin enlaces, como en el
panel.

«Crear mi cuenta» va en la `BarraDeAccion`, sobre el teclado. Si falta algo,
cada campo dice qué y la pantalla baja al primero con error; no se envía
nada. El envío es `POST /auth/registro` (pública) con los campos que deja
pasar el gateway (`CAMPOS_REGISTRO`) y `aceptaTerminos: true`. Si el
servidor no crea la cuenta (400 con el motivo, 409 si el correo o el
documento ya tienen cuenta, 429 si se crearon demasiadas desde la misma
conexión), su mensaje se ve una sola vez, sobre el botón, y el formulario
queda como estaba. Los campos tienen su `textInputAction` (del documento se
sigue a la fecha si falta) y sus pistas de autocompletado (nombre, correo,
teléfono, contraseña nueva, para que el gestor de contraseñas la guarde).

Creada la cuenta, **«Revisa tu correo»**: el correo al que se mandó el
enlace, «Reenviar enlace» (`POST /auth/registro/reenviar`), apagado los
segundos de `seguridad.reenvioSegundos` con la cuenta a la vista («Reenviar
en 42 s»), y «Volver a ingresar», que vuelve al acceso con el correo
escrito. El estado vive en `RegistroBloc` (`features/auth/providers/`).

## Enlaces de los correos (App Links y Universal Links)

Los dos correos de la cuenta traen un enlace al panel, armado por el API
con `general.frontendUrl` (o `FRONTEND_URL`):
`https://cliniq.gcaicedo-proyectos.com/confirmar-correo?token=…` al crear la
cuenta y `https://cliniq.gcaicedo-proyectos.com/restablecer?token=…` al
pedir una contraseña nueva (`auth-ms/src/auth/notifications/auth-mailer.service.ts`;
son las mismas rutas del panel, `app.routes.ts`). Tocados en el teléfono
con la aplicación instalada, **abren la aplicación**:

- `/confirmar-correo` → `ConfirmarCorreoPage`: confirma sola
  (`POST /auth/registro/confirmar { token }`) y dice «¡Listo! Tu cuenta está
  activa» con «Ingresar»; un enlace vencido o ya usado (400) dice el motivo
  del servidor y deja pedir otro con el correo (`/auth/registro/reenviar`);
  sin red, «Reintentar» con el mismo enlace.
- `/restablecer` → `RestablecerPage`: la contraseña nueva y su
  confirmación, con el mínimo de la clínica y la barra de fortaleza
  (`POST /auth/password/restablecer { token, newPassword }`); guardada,
  «Contraseña actualizada» con «Ingresar»; un enlace vencido dice el motivo
  y ofrece «Pedir otro enlace».

Los recibe `app_links` y los lee `leerEnlaceEntrante`
(`features/navegacion/dominio/enlaces_entrantes.dart`: `https`, el servidor
de `WEB_URL`, una de las dos rutas y el `token`); `ReceptorDeEnlaces`
abre la pantalla encima de lo que se esté viendo, con la aplicación cerrada
o abierta. Solo esas dos rutas abren la aplicación: el resto del panel sigue
en el navegador. **Sin la aplicación instalada** (o en una computadora), el
mismo enlace abre el panel, que confirma o restablece igual: los correos no
cambian.

### Lo que tiene que llenar el dueño

La verificación la hacen Android e iOS contra dos archivos que sirve el
panel: `public/.well-known/assetlinks.json` y
`public/.well-known/apple-app-site-association` (sin extensión), en el
repositorio `dashboard-cliniq`. El nginx del contenedor del panel los sirve
como `application/json`, sin redirecciones y con 404 si faltan (nunca la
página del panel). Traen dos marcadores que hay que reemplazar:

1. **La huella SHA-256 del certificado de firma de Android** →
   `sha256_cert_fingerprints` de `assetlinks.json` (reemplaza
   `REEMPLAZAR:CON:LA:HUELLA:SHA-256:DEL:CERTIFICADO:DE:FIRMA:DE:LA:APLICACION`).
   - Si la aplicación se publica en Google Play con la firma de apps de
     Google (lo normal), la huella es la de **la clave de firma de apps de
     Google**, no la de subida: Play Console → la aplicación → *Probar y
     publicar* → *Configuración* → *Integridad de la app* → *Firma de apps*
     → «Certificado de la clave de firma de apps» → **SHA-256**. En esa
     misma página, «Digital Asset Links JSON» da el archivo ya armado.
   - Para probar un APK firmado en la computadora (sin pasar por Play),
     agrega también la huella de esa clave, la de `android/key.properties`:
     `keytool -list -v -keystore <storeFile> -alias <keyAlias>` (o
     `cd android && ./gradlew signingReport`), línea «SHA256:». Para una
     compilación de depuración, la del almacén de depuración:
     `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`.
   - Van como texto, en mayúsculas y con dos puntos
     (`"AB:CD:…:EF"`), una por elemento de la lista; puede haber varias.
2. **El Team ID de Apple** → `appIDs` de `apple-app-site-association`:
   reemplaza `REEMPLAZAR_TEAM_ID` para que quede
   `<TEAM_ID>.ec.cliniq.sage.app`. El Team ID (diez caracteres) está en
   developer.apple.com → *Account* → *Membership details* → **Team ID**. El
   proyecto de Xcode tiene hoy `DEVELOPMENT_TEAM = 47K98K5Q7X`: si es el
   equipo que firma la publicación, ese es el valor.
3. **La capacidad en Apple.** El App ID `ec.cliniq.sage.app` necesita
   «Associated Domains»: con la firma automática de Xcode se activa sola al
   compilar con `Runner.entitlements`; con firma manual, en
   developer.apple.com → *Certificates, Identifiers & Profiles* →
   *Identifiers* → `ec.cliniq.sage.app` → marcar **Associated Domains**, y
   volver a generar el perfil de aprovisionamiento.
4. **Publicar el panel** con los dos archivos (la rama `main` del panel se
   despliega sola) y comprobar desde cualquier computadora:
   ```bash
   curl -sI https://cliniq.gcaicedo-proyectos.com/.well-known/assetlinks.json
   curl -sI https://cliniq.gcaicedo-proyectos.com/.well-known/apple-app-site-association
   ```
   Los dos: `HTTP/1.1 200` y `Content-Type: application/json`, sin
   redirección. Google lo confirma en
   `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://cliniq.gcaicedo-proyectos.com&relation=delegate_permission/common.handle_all_urls`
   (tiene que listar `ec.cliniq.sage.app` con la huella) y Apple, que lo
   descarga a su red, en
   `https://app-site-association.cdn-apple.com/a/v1/cliniq.gcaicedo-proyectos.com`
   (puede tardar hasta un día en tomar un cambio).

Si algún día cambia el dominio del panel (`WEB_URL`), cambian con él: el
`android:host` del `intent-filter` en `AndroidManifest.xml`, el
`applinks:` de `Runner.entitlements`, los dos archivos en el dominio nuevo y
`general.frontendUrl` (o `FRONTEND_URL`) en el API.

### Qué verificar en el teléfono

- **Android** (con una compilación firmada con una clave cuya huella está en
  `assetlinks.json`: la de Play, desde una prueba interna, o la de subida):
  - después de instalarla, `adb shell pm get-app-links ec.cliniq.sage.app`
    dice `cliniq.gcaicedo-proyectos.com: verified` (si no, forzar la
    verificación con `adb shell pm verify-app-links --re-verify ec.cliniq.sage.app`
    y volver a mirar);
  - `adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://cliniq.gcaicedo-proyectos.com/confirmar-correo?token=prueba"`
    abre la aplicación, sin preguntar con qué, en «El enlace no es válido o
    ya venció» (el token es de mentira); lo mismo con `/restablecer`, en
    «Crea una contraseña nueva»;
  - de punta a punta: crear una cuenta desde la aplicación, tocar el enlace
    del correo en Gmail → la aplicación abre «¡Listo! Tu cuenta está activa»
    e «Ingresar» entra; «¿Olvidaste tu contraseña?», tocar el enlace →
    «Crea una contraseña nueva», guardar, entrar con la nueva;
  - con la aplicación abierta en otra pantalla, y con la aplicación cerrada:
    en los dos casos se abre la pantalla del enlace;
  - cualquier otra dirección del panel (por ejemplo `/login`) sigue
    abriéndose en el navegador.
- **iOS** (TestFlight o Xcode en un teléfono de verdad; en el simulador no
  se verifica):
  - tocar el enlace en Mail o en Notas abre la aplicación; al mantenerlo
    presionado se ofrece «Abrir en Cliniq». Escrito en la barra de Safari no
    abre la aplicación: así funcionan los Universal Links;
  - si la aplicación se instaló antes de que el archivo estuviera publicado,
    borrarla e instalarla de nuevo (iOS lo descarga al instalar);
  - los mismos recorridos que en Android.
- **Sin la aplicación** (o en una computadora): los dos enlaces abren el
  panel y confirman o restablecen como siempre.

## Páginas de fuera

Un enlace externo del menú (el que puso el administrador) y los enlaces
`http(s)` de los artículos de ayuda y de los documentos legales se abren en
`PaginaWebPage` (`core/presentacion/pagina_web_page.dart`, por
`abrirPaginaWeb` de `core/presentacion/enlaces.dart`): un WebView de la
aplicación (`flutter_inappwebview`, el de la videoconsulta) bajo la cabecera
de Cliniq, con el título (el nombre del enlace, si no el de la página, si
no el servidor), el servidor con su candado, «Cerrar» y «Recargar», y la
barra de carga. Nunca Chrome Custom Tabs, Safari ni el navegador del
teléfono.

- Dentro de la página se navega como siempre; las ventanas nuevas
  (`target="_blank"`) se cargan en la misma pantalla. El botón atrás vuelve
  a la página anterior y, en la primera, cierra.
- `tel:` y `mailto:` tocados van al marcador o al correo del teléfono (lo
  único que sale de la aplicación, con `url_launcher`); una página no puede
  abrirlos sola. Todo lo demás (`intent:`, `market:`, `whatsapp:`, `file:`,
  `javascript:`…) se bloquea.
- La página no recibe permisos (cámara, micrófono, ubicación) ni puente con
  la aplicación. Si no carga, lo dice con «Reintentar».

Las decisiones son funciones puras (`core/web/navegacion_web.dart`); el
WebView vive solo en `core/web/vista_web.dart`, detrás de
`FabricaDeVistaWeb` (`Servicios.vistaWeb`), así que las pruebas abren la
pantalla con una vista de mentira.

## Fechas: la hora de la clínica «congelada»

La API guarda la hora local de la clínica como si fuera UTC: las 09:00 de
Quito se guardan `2026-09-28T09:00:00.000Z`. Leerla como un instante de
verdad la movería cinco horas. `lib/core/fechas/fecha_local.dart`:

- `aFechaLocal` / `leerFechaLocal` **descartan la zona y nunca convierten**:
  la cadena dice las 09:00 y la aplicación enseña las 09:00. Rechazan las
  fechas imposibles en vez de desbordarlas.
- `aTextoLocal` escribe `YYYY-MM-DDTHH:mm:ss`, sin zona, que es lo que la API
  exige.
- `RelojClinica` da la hora de la clínica esté donde esté el teléfono, en la
  zona de su configuración (`clinica.zonaHoraria`, con la base de zonas de
  `timezone`: una zona con horario de verano también queda bien): las horas
  para cambiar una cita y los horarios que ya pasaron se comparan contra la
  clínica.

Está cubierto por `test/fecha_local_test.dart`.

### Los instantes reales

Las consultas en línea, sus mensajes, los archivos y los eventos de video
**no** son hora congelada: son instantes de verdad en UTC con `Z`. Para ellos
es `lib/core/fechas/instante.dart`: `leerInstante` respeta la zona (y toma
como UTC una cadena sin ella) y `enHoraDeLaClinica` los convierte a la zona
de la clínica para enseñarlos. El plazo de una consulta se compara con
`RelojClinica.instante()`, no con `ahora()`. Pasar uno de estos por
`leerFechaLocal` los dejaría cinco horas corridos, y al revés con las citas.
Cubierto por `test/instante_test.dart`.

## Agendar: los turnos los calcula la API

La aplicación no calcula huecos. Los turnos libres llegan de la API, que usa
las mismas reglas con que valida la reserva (jornada, bloqueos, duración,
margen, límite diario, anticipación, horizonte y rejilla):

- `GET /portal/proximos-turnos` (con `ciudad` y `modalidad` opcionales): las
  especialidades con cuántos médicos tienen turnos libres y el primero de
  ellos («El primer turno disponible»), y solo esos médicos, cada uno con su
  próximo turno. El buscador por nombre filtra esa lista en el teléfono.
- `GET /portal/turnos/:doctorId?modalidad=…`: los turnos de un médico, de hoy
  al horizonte de la clínica. Al reprogramar se manda `excluirCita` y el
  horario de la propia cita (y los de al lado) se ofrecen libres.
- Si la cita es para un dependiente, las dos rutas llevan su `pacienteId` y
  la API quita los turnos en que ya tiene una cita; para el titular no se
  manda. Cambiar «¿Para quién?» vuelve a pedir los dos.

`lib/features/agendar/dominio/huecos.dart` solo presenta: los días con
turnos, las fichas de un día en mañana, tarde y noche con los cortes de la
configuración (`agenda.horaInicioTarde`, `agenda.horaInicioNoche`) y las
palabras naturales («hoy a las 15:30», «mañana», «lun 29»). Las fechas son
hora local de la clínica (`clinica.zonaHoraria`).

Sin red no se inventa nada: se dice que no se pudo y se ofrece reintentar.
Si al agendar o reprogramar la API responde 409 (el turno se tomó
entretanto), se enseña su mensaje, se vuelven a pedir los turnos y los
próximos turnos, se conserva todo lo elegido y se vuelve a la hora sin ese
turno. Cualquier error que explica el servidor se enseña con su mensaje, una
sola vez y en un solo lugar.

Una diferencia a propósito con el web: solo se ofrecen las especialidades
con algún médico disponible. En un teléfono, elegir una especialidad sin
turnos es un callejón sin salida.

## Consultas en línea

El paciente le escribe a un médico sin cita (`portal.consultas`), para sí o
para un dependiente, y el médico responde en el plazo de la clínica
(`telemedicina.horasRespuesta`). Todo va por
las rutas del paciente de `/portal/consultas`
(`lib/features/consultas/data/consultas_service.dart`).

- **Lista** (se abre desde el inicio): borradores —seguir o eliminar—, en
  curso —primero las que tienen respuesta del médico por leer— y anteriores.
  Cada tarjeta dice el estado, el plazo que le queda al médico («Quedan
  36 h», «Demorada», recalculado cada minuto contra el instante real) y para
  quién es.
- **Consulta nueva**, un paso por pantalla como el agendamiento: para quién
  → especialidad → motivo (con su descripción y si pide un archivo) → médico
  → el formulario del motivo (`texto`, `textoLargo`, `numero` con su unidad,
  `seleccion`, `siNo`, `fecha`), la descripción y los archivos → resumen →
  enviar. Los errores se marcan al intentar seguir.
- **Archivos**: cámara, galería o archivos del teléfono; los tipos y el
  tamaño de la configuración (`archivos.tipos` —PDF, JPG, PNG, WEBP o HEIC—
  y `archivos.tamanoMaximoMb`), hasta `telemedicina.maxArchivosConsulta` por
  consulta, validados **antes** de subir con las mismas reglas del servidor
  (el tipo por la firma del contenido, la extensión corregida si no
  coincide). Las fotos se reducen al elegirlas.
- **Enviar** son tres pasos: crear el borrador (`POST`), subir los archivos
  uno por uno (`POST …/adjuntos`, multipart, campo `archivo`) y enviar
  (`POST …/enviar`). Si algo falla a mitad, lo hecho queda en el borrador y
  reintentar sigue desde ahí, sin crear otra consulta ni volver a subir lo
  subido. También se puede guardar como borrador y retomarlo (el paciente,
  el motivo y el médico quedan fijos: el servidor solo deja cambiar las
  respuestas, la descripción y los archivos) o descartarlo; al salir con
  cambios se ofrece guardarlos. Al retomarlo, las preguntas y si hace falta
  un archivo salen de la copia que el borrador tomó del motivo al crearse
  (`campos` y `requiereAdjunto` del detalle, lo que valida el envío), no del
  motivo de `/opciones`, que el administrador pudo editar después.
- **Detalle**: estado y plazo (o «tu consulta está demorada, la clínica ya
  fue avisada»), lo que se contó, los archivos —las imágenes en un visor con
  zoom, bajadas con la sesión y sin copiarlas al teléfono; los PDF con el
  visor del sistema—, la conversación en burbujas y, cuando `puedeEscribir`,
  el redactor con un archivo opcional. Mientras está ENVIADA se puede
  cancelar con un motivo (obligatorio, hasta 500 caracteres con su
  contador, el tope del servidor). Se desliza para refrescar (vuelve a pedir
  el detalle) y, **solo mientras la pantalla se ve**, pregunta por novedades
  cada 30 segundos: se apaga con otra pantalla encima (`observadorDeRutas`),
  con la aplicación en segundo plano o con la consulta CERRADA o CANCELADA,
  y al volver pregunta enseguida. El sondeo pide la lista de resúmenes
  (`GET /portal/consultas`) y solo vuelve a pedir el detalle si esta
  consulta cambió de `estado`, `totalMensajes` o `ultimoMensajeEn` (o si se
  estaba viendo la copia guardada): cada lectura de `GET
  /portal/consultas/:id` queda en la bitácora de la historia clínica, y
  pedirlo cada 30 segundos la llenaba. Al escribir o cancelar se usa la
  consulta que devuelve el servidor, sin volver a pedirla.

## Mi salud, centro de ayuda y soporte

Tres pantallas nativas que el enrutador abre por su ruta: `MiSaludPage()`
(`/mi-salud`), `CentroAyudaPage()` (`/ayuda`), `SoportePage()` (`/soporte`)
y `TicketPage(id: …)` (`/soporte/tickets/:id`). Cada respuesta se guarda en
el teléfono tal como llegó (por persona; se borra al cerrar sesión) y sin
red se enseña esa copia; sin copia, el error con «Reintentar».

- **Mi salud** (`GET /portal/mi-salud`, `?pacienteId=` para un dependiente):
  la ficha con las alergias, el embarazo en curso, las últimas mediciones y,
  por consulta, diagnósticos, indicaciones, recetas, órdenes, certificados
  de reposo y adjuntos. Cada receta, orden y certificado se abre en su
  pantalla (`/portal/recetas/:id`, `/portal/ordenes/:id`,
  `/portal/certificados/:id`) con su número, la modalidad de la atención y
  su código de verificación. Las fechas clínicas son hora congelada. Ver
  «Recetas, órdenes y certificados».
- **Centro de ayuda** (`GET /ayuda?q=`): el servidor busca; sin red se busca
  con la misma regla sobre la copia. Primero va **«Tu guía»**: la guía de
  usuario de quien entra (el servidor manda solo la de sus roles; se
  reconoce por el artículo principal, de clave `guia.<rol>`, que va
  arriba), teñida; después las demás categorías. Los artículos
  `contextual` (los textos de los «?») no se listan. El Markdown del artículo se pinta con
  widgets (párrafos, títulos, negrita, listas y enlaces). Un enlace nunca
  saca de la aplicación: las rutas de ayuda, soporte y Mi salud abren su
  pantalla, las de otros módulos van al enrutador (`abrirRuta`), la web se
  abre en la pantalla de páginas web de la aplicación y `mailto:` y `tel:`
  siguen igual. Al final de cada
  artículo, «¿No resolviste tu duda?» abre soporte con el ticket nuevo.
- **Soporte** (`/soporte/tickets`): el ticket nuevo valida con los límites
  del servidor (asunto 3–150, descripción 10–5000, mensaje hasta 5000) y
  sube el archivo después de crearlo, en un mensaje «Adjunto: …», como el
  panel. Los mensajes solo traen el id del adjunto: el nombre y el tipo
  salen de las cabeceras de la misma descarga; una imagen se ve en el visor
  de la aplicación y un PDF, con el visor del teléfono.

## Recetas, órdenes y certificados

El médico firma la receta, la orden o el certificado de reposo con su
certificado `.p12` (en el servidor, durante la petición; nunca se guarda),
y el servidor guarda el PDF firmado en MinIO con su sha256. La aplicación
lee de cada documento `firmado`, `pdfDisponible` y `firma` (quién firmó
—el nombre del certificado—, cuándo, el emisor y la huella del PDF), y
también `numero` (el secuencial de la clínica, «N.º 000123») y
`modalidad` (código de `MODALIDAD_CITA`, con el nombre de su catálogo).
Todo es opcional: los documentos viejos se leen y se enseñan igual.

- **La receta, en sus dos partes** (`RecetaPage`), como la receta
  ecuatoriana: **«Para la farmacia»** (cada medicamento por su nombre
  genérico, la concentración, la forma farmacéutica y la cantidad en
  números y en letras, `cantidad` y `cantidadEnLetras`) y **«Cómo
  tomarlo»** (dosis, frecuencia, duración, vía e indicaciones de cada
  uno, las recomendaciones y los **signos de alarma**, `signosAlarma`,
  con el número de emergencias de la clínica). Si la atención fue a
  distancia (telemedicina o consulta en línea) y la receta no está
  firmada, avisa que así no es válida para dispensar.
- **La orden** (`OrdenPage`): «Orden de laboratorio», «de imagen» o «de
  exámenes», la prioridad, **cómo prepararse** (`preparacion`), los
  exámenes agrupados por área (`grupo` de cada ítem, el área del catálogo
  de exámenes) con sus indicaciones, las **indicaciones clínicas**
  (`indicacionesClinicas`) y las observaciones.

- **Certificado de reposo** (`CertificadoPage`): los días en número y en
  letras, desde y hasta (días sueltos; sin `fechaHasta`, desde + días − 1),
  reposo absoluto o relativo, la contingencia, la modalidad de la atención
  (con el nombre de su catálogo), a quién va dirigido, las recomendaciones,
  quién lo emitió y el código de verificación. **El diagnóstico aparece solo
  si el servidor lo manda y el certificado no lo reserva**
  (`mostrarDiagnostico`); si lo reserva, «Diagnóstico reservado», como en el
  PDF. Los códigos (`tipoReposo`, `contingencia`, `destinatario`) son del
  sistema y se nombran en `dominio/reglas_mi_salud.dart`.
- **Entrega al firmar:** si la clínica entrega los documentos al firmar
  (`clinico.entregarDocumentosAlFirmar`), Mi salud trae también la consulta
  todavía abierta (`enCurso`) con lo ya firmado y sin contenido clínico: se
  marca «En curso» y lo explica.
- **La firma:** en la lista, la pastilla «Firmada electrónicamente» /
  «Firmado electrónicamente»; en el documento, el sello «Firmado
  electrónicamente por <nombre> el <día> a las <hora>» (el instante real,
  en la hora de la clínica) con el emisor del certificado. Una reserva en
  curso (`EN_CURSO`) no es una firma y no se enseña.
- **«Ver PDF»**, en todo documento que no esté anulado: abajo en la
  receta, la orden y el certificado (en la `BarraDeAccion`) y en su fila
  de Mi salud. Abre `VisorPdfPage`, que baja
  `GET /portal/{recetas|ordenes|certificados}/:id/pdf` con la sesión y lo
  pinta **dentro de la aplicación** con `pdfx`. Nunca otra aplicación ni
  el navegador. Firmado, el servidor da el PDF guardado; **sin firma, la
  vista previa** (el mismo diseño con el recuadro «Documento sin firma
  electrónica»), y el visor lo dice arriba (el documento no está firmado
  o el servidor respondió `X-Firma-Estado: SIN_FIRMA`). Si el servidor no
  lo da (la clínica lo entrega solo firmado), se enseña **su mensaje**.
  Abajo, «Guardar en el teléfono» (el diálogo del sistema) y «Compartir»
  (la hoja del sistema), con un nombre legible («Receta UC7F6DB5UU.pdf»,
  «Orden de laboratorio G2KKBTJTBK.pdf»).
- **La copia en el teléfono** (`DocumentosPdfService`): cada PDF bajado se
  guarda en la carpeta de documentos de la aplicación,
  `cliniq_documentos/<tipo>_<id>_<sha256>.pdf`. El servidor nunca regenera
  un PDF firmado, así que la copia sirve siempre: con la huella del
  documento se abre la copia sin pedir nada; sin red, la última copia de
  ese documento, y la pantalla lo dice. La vista previa sin firma se
  vuelve a pedir cada vez (y su copia es la última que dio el servidor);
  una vez firmado, con la huella nueva, la copia de la vista previa ya no
  sirve y nunca se hace pasar por la firmada. Lo que se baja tiene que empezar
  como un PDF y, si se conoce la huella, coincidir con ella; si no, no se
  guarda ni se enseña. Cada copia se comprueba al abrirla contra la huella
  de su nombre, y una dañada se borra.
- **Se borran al cerrar sesión (y al vencer la sesión).** Es una decisión:
  son datos de salud y el teléfono puede ser compartido, igual que las
  citas y los adjuntos descargados. Con ellos se borra lo que ver, guardar
  o compartir deja en la carpeta temporal (la copia con nombre legible, la
  que `share_plus` hace en Android y las páginas que `pdfx` pinta en
  Android). Lo que la persona guardó en el teléfono con «Guardar en el
  teléfono», o compartió, ya es suyo y no se toca. Al volver a entrar, el
  PDF se baja de nuevo la primera vez. En iOS la carpeta de documentos
  entra en la copia de seguridad del teléfono (iCloud) mientras la sesión
  sigue abierta; si la clínica no lo quiere, la alternativa es la carpeta
  de soporte de la aplicación marcada fuera de la copia.

## Mis signos vitales

Lo que el paciente mide en casa, para que su médico lo vea en la consulta
(`/portal/mediciones`; `lib/features/mediciones/`). Se entra desde **Mi
salud** (del titular o del dependiente elegido), desde el **detalle de una
cita de telemedicina pendiente** («Mis signos vitales para esta cita»),
desde una **consulta en línea abierta** («Compartir mis signos vitales») y
por la ruta `/portal/mediciones` (el administrador la puede poner en el
menú). Todo depende de `telemedicina.medicionesPacienteActiva`: apagado, no
hay accesos ni «Registrar».

- **La lista**, por día en la hora de la clínica, la más reciente arriba:
  el valor con su unidad, el tipo, la hora y el momento, y sus insignias:
  «Cámara · experimental», «Aparato de casa» o «A mano»; la calidad de las
  de la cámara (buena, regular o baja); «Enviada a tu médico» y «Usada en
  una atención». Lo propio que el médico no usó se puede borrar (pregunta
  antes; el servidor lo comprueba). «Ver mediciones anteriores» pide la
  página siguiente.
- **Dos pestañas: «Tendencias» y «Registro».** «Registro» es la lista de
  arriba. «Tendencias» (la que abre) pide al servidor las mediciones del
  periodo elegido —**7 días, 30 días o 3 meses**— con `desde` y
  `limit=100` (hasta 5 páginas), y enseña una tarjeta por tipo con datos
  (FC, PA, SpO2, temperatura, glucosa, peso y FR): el último valor con su
  fecha y su etiqueta de rango, el mínimo, el promedio y el máximo del
  periodo y una gráfica de línea (`fl_chart`) con la **franja del rango de
  referencia para adultos** y el texto «Referencia para adultos». Los
  puntos de la cámara son cuadrados y los de los aparatos (o a mano),
  círculos, con su leyenda. Sin red, la tendencia usa lo que ya está en el
  teléfono y lo dice. El cálculo es puro y probado
  (`dominio/tendencias.dart`).
- **Rangos de referencia para adultos** (`dominio/rangos_referencia.dart`,
  los mismos del panel): FC 60–100 lpm, FR 12–20 rpm, PA 90–120 / 60–80
  mmHg, SpO2 95–100 %, temperatura 36,0–37,5 °C, glucosa 70–100 mg/dL en
  ayunas; el peso no tiene. Dan la etiqueta «En rango (60–100)», «Alta» o
  «Baja» y la franja de las gráficas. No son los rangos que acepta el
  servidor (`rangoDelTipo`, mucho más anchos).
- **«Registrar»**: el tipo (presión, pulso, saturación, temperatura,
  glucosa, peso o respiraciones), el valor —la presión con la alta y la
  baja—, cómo se midió (con un aparato; el pulso y las respiraciones,
  también contando a mano), el momento (en reposo o tras actividad; en
  ayunas o después de comer para la glucosa) y la hora, que por defecto es
  ahora (de los últimos 30 días, en la hora de la clínica). Se valida con
  los rangos del servidor (FC 30–220, FR 6–60, PA 60–260 / 30–160 con la
  sistólica mayor, SpO2 70–100, temperatura 34–43, glucosa 20–600, peso
  1–400) y la unidad la fija el servidor. Abierto desde una cita o una
  consulta, ofrece «Compartir con mi médico» (`citaId` o `consultaId`).
- **«Medir con la cámara (experimental)»**, solo si
  `telemedicina.escanerCamaraActivo` (ver «Escáner experimental»).
- **Sin red** (`ColaMediciones`): registrar intenta enviar; sin conexión,
  el envío queda en la caché cifrada (`mediciones-pendientes:<uid>`) y se
  enseña como «Pendiente de enviar». Sale solo al entrar, al volver a la
  aplicación, al recuperar la red (`EnvioDeMedicionesPendientes`, en
  `main.dart`) y al abrir la pantalla. Si el servidor lo rechaza (400: un
  valor fuera de rango, más de 30 días; 409: la cámara apagada), queda
  marcado con su mensaje, no se reintenta y la persona lo descarta. Lo
  pendiente es de la persona: se borra al cerrar sesión, como todo lo
  personal. Nunca se inventa nada: lo pendiente son números que la persona
  escribió o midió, y no se hacen pasar por guardados en la clínica.
- **El servicio** (`MedicionesService`): `GET /portal/mediciones` (el
  titular sin `pacienteId`; un dependiente, con el suyo), con copia de la
  primera página para verla sin red; `POST` con hasta 10 mediciones;
  `DELETE /portal/mediciones/:id`. El contrato dice «paginadas» sin fijar
  la forma: se leen `{items, total, page, limit}` (o `pagina`/`limite`),
  `{items, hayMas}` y una lista sola, y la página siguiente se pide con el
  nombre de parámetro que use el servidor.

## Escáner experimental

Mide la **frecuencia cardiaca** con la cámara y, con buena calidad, la
**frecuencia respiratoria aproximada**. **Nunca presión, saturación,
temperatura ni glucosa**: sin hardware específico no son confiables y se
registran desde los aparatos de casa (el aviso lo explica). Lo enciende el
administrador (`telemedicina.escanerCamaraActivo`, apagado por defecto) y
dura `telemedicina.escanerSegundos` (30 por defecto). **No es un
dispositivo médico**: se rotula experimental y referencial, y el médico
decide si usa el valor (queda marcado su origen).

- **La primera vez**, el aviso: «Función experimental: no es un dispositivo
  médico. Los valores son referenciales; no la uses para decidir
  tratamientos. Ante síntomas de alarma llama al
  {{clinica.telefonoEmergencia}}», con «Entiendo», recordado en la caché
  cifrada por persona (`escaner-aviso:<uid>`).
- **Modos**: el **rostro** es el modo de siempre. El **dedo** es opcional
  y viene apagado (`telemedicina.escanerDedoActivo`): en un teléfono con
  varias cámaras no siempre se sabe cuál cubrir. Apagado, no hay selector y
  se entra directo al rostro; encendido, el selector ofrece primero «Con tu
  rostro (recomendado)» y después «Con el dedo (alternativo)»: «Cubre con
  la yema la lente que está junto a la luz que se enciende». El lector de
  huellas no sirve: Android e iOS solo le dicen a la aplicación «es el
  dueño» o «no lo es», nunca la imagen ni la señal.
- **Mientras mide, con el rostro (a pantalla completa)**: la cámara frontal
  cubre toda la pantalla, espejada, con una viñeta oscura fuera de un marco
  grande (80 % del ancho, en proporción de rostro) y **cuatro esquinas que
  respiran** (de 1,00 a 1,03) y cambian de color: blanco al buscar, ámbar
  al ajustar, verde al medir. Encima, una **malla de alambre** con los
  contornos que detecta ML Kit (triangulación de Delaunay propia), con
  puntos que brillan y **laten al ritmo de la FC en vivo** (sin ella, con
  un ritmo lento y neutro), suavizados entre detecciones para verse
  fluidos; aparece y desaparece con un fundido. Una **línea de barrido**
  recorre el marco cada 2,5 s. **Sin ML Kit no hay malla**: solo las
  esquinas y el barrido. Con las animaciones del sistema apagadas no hay
  latido ni barrido.
  - Arriba: cerrar, «Signos vitales · Experimental» y **la guía**, una
    instrucción a la vez: «Pon tu cara dentro del marco», «Acércate un
    poco» (la cara ocupa menos del 35 % del ancho), «Aléjate un poco» (más
    del 85 %), «Centra tu cara», «Mira de frente a la cámara» (giro de más
    de 15° o inclinación de más de 12°), «Quédate quieto» (la caja se
    mueve), «Busca un lugar con más luz» y «Perfecto, no te muevas».
  - **Arranca sola**: la cuenta empieza cuando la cara está bien encuadrada
    1 s seguido, con un toque háptico; antes se ve «Preparando…». Si la
    cara se pierde más de 2 s, la cuenta **se pausa** («En pausa · 18 s»)
    y se quitan de la serie esos cuadros; al volver bien encuadrada sigue
    sin el hueco. Si no vuelve en 8 s, se detiene con un consejo y
    «Reintentar».
  - Abajo, un panel oscuro translúcido: «Frecuencia cardiaca» en vivo
    (aparece a los 8–10 s con calidad regular o mejor, con la etiqueta «en
    vivo»; antes, «—» con un brillo de carga), «Respiración» («—» hasta el
    final), «Calidad de señal» con su barra, la onda con **los latidos
    detectados marcados**, una mini gráfica de la FC de cada segundo,
    «Latidos detectados: N», la barra de avance con «Tomando la medición…
    18 s», «Cancelar» y «El video se analiza en tu teléfono y nunca se
    guarda ni se envía». La FC en vivo es solo una guía: el valor final es
    el del análisis de la medición entera.
- **Mientras mide, con el dedo**: el círculo que late, el consejo del
  momento («Cubre bien la cámara y el flash con la yema», «Apoya el dedo
  sin apretar», «Quédate quieto») y el mismo panel; mide desde el primer
  cuadro.
- En los dos: si la calidad se queda por debajo de 0,3 durante 8 segundos,
  se detiene con un consejo y «Reintentar». Si la cámara deja de enviar
  cuadros 5 segundos o la aplicación pasa a segundo plano, también. La
  cuenta va con el tiempo de los propios cuadros. Al terminar, un toque
  háptico.
- **El resultado**: tarjetas en dos columnas que entran escalonadas, con
  los números subiendo: la FC con su etiqueta de rango («En rango
  (60–100)», «Alta», «Baja»), la FR en rpm si la calidad es ≥ 0,6 y hay un
  pico respiratorio claro, la variabilidad (SDNN y RMSSD en ms) si la
  calculó el servidor, y la calidad (buena desde 0,7, regular desde 0,4,
  baja por debajo; por debajo de 0,3 no se da ningún valor: «No pudimos
  medir esta vez» con un consejo). Una tarjeta honesta, «Presión y
  saturación: regístralas con tu tensiómetro u oxímetro», lleva a
  «Registrar». También el momento (en reposo o tras actividad) y quién lo
  calculó: «Calculado en el teléfono» o «Analizado en el servidor
  (experimental)».
- **«Detalle de la medición»**, debajo: calculado **en el teléfono** con la
  misma serie aunque el resultado sea del servidor («Detalle calculado en
  tu teléfono»), y sin guardarse. Datos en tarjetas pequeñas, solo con la
  calidad que los sostiene: intervalo medio entre latidos, FC mínima y
  máxima, latidos detectados, y con buena calidad, 30 s o más y 20
  intervalos, pNN50, SD1 y SD2; siempre la duración y la calidad (%). Seis
  gráficas con su explicación sencilla: la onda del pulso con sus latidos,
  la FC durante la medición con la franja de 60 a 100, los intervalos entre
  latidos (tacograma), Poincaré con SD1 y SD2, el espectro de 42 a 210 lpm
  con el pico de la FC y la onda lenta de la respiración (solo con FR).
  Sin datos suficientes, «No hay suficiente señal para esta gráfica».
  Nunca estrés, SpO2, presión, LF/HF ni nada que 30 s de cámara no
  sostengan.
- Después, «Guardar en mis signos vitales», «Enviar a mi
  médico» (adjunta la medición a la **próxima cita de telemedicina** o a
  una **consulta en línea abierta** de ese paciente, la que la persona
  elija; abierto desde una cita o una consulta, a esa) o «Descartar». Se
  guardan `FC` (y `FR` si salió) con el método `CAMARA_DEDO` o
  `CAMARA_ROSTRO`, la calidad y el motor en las notas («motor: interno-ppg
  v1»).
- **Privacidad** (LOPDP), dicho en una línea en cada paso: **ninguna imagen
  se guarda ni se envía**. `FuenteCamara` reduce cada cuadro, en el
  momento, a unos pocos promedios (`CuadroPpg`) y lo suelta (ML Kit lo
  analiza en el mismo teléfono y puede mandar a Google métricas anónimas
  de uso de la librería, nunca imágenes); los números se
  juntan solo mientras dura la medición y se borran al terminar, cancelar o
  descartar. Al servidor solo llegan números: el resultado y, para el
  análisis experimental, la serie de promedios por cuadro.

### Cómo funciona

```
cámara ─► FuenteCamara ─► CuadroPpg ─► SerieSenal ─► MotorSignosCamara ─► ResultadoEscaner
          (camera)        (números)    (números)     MotorInterno, o el servidor
```

- **La fuente** (`FuenteDeCuadros`, inyectable): la de verdad,
  `FuenteCamara`, abre la frontal en resolución media (ML Kit necesita
  caras de unos 200 píxeles para los contornos) o la trasera con la
  linterna en la más baja (y fija la exposición y el enfoque al
  encenderla), a 30 cuadros por segundo; las pruebas usan `FuenteFalsa`
  con señales sintéticas y `FuenteDeImagenesFalsa`, que pasa imágenes
  sintéticas por el procesador del rostro de verdad.
- **El rostro** (`escaner/rostro/`): `DetectorDeRostro` (interfaz;
  `DetectorMlKit` con contornos, modo rápido y sin clasificación, y uno
  falso en las pruebas) devuelve `RostroDetectado` —la caja, los contornos,
  los ángulos Y y Z— en las coordenadas de la imagen derecha y espejada
  como la ve la persona (en Android se gira según el sensor y el teléfono y
  se espeja la frontal; en iOS el paquete `camera` ya la entrega así).
  `ProcesadorDeRostro` detecta como mucho ~10 veces por segundo sin
  bloquear (si hay una detección en curso, el cuadro sigue) y promedia el
  RGB en **cada** cuadro con la última región conocida: la frente (sobre
  las cejas) y las dos mejillas (entre el ojo, la nariz, el labio y el
  óvalo), y de ahí solo la piel (YCbCr); como mucho ~900 píxeles por
  cuadro. Si ML Kit no se puede crear o falla dos veces seguidas, sigue
  con `ExtractorDeRostro` (color de piel en el marco) sin cortar. La guía
  (`guia_encuadre.dart`), la triangulación (`delaunay.dart`, Bowyer–Watson)
  y el suavizado son puros y probados.
- **La cuenta** (`ControlDeMedicion`, puro): el arranque solo, la pausa y
  la pérdida del rostro. **En vivo** (`EstimadorEnVivo`, puro): cada
  segundo, sobre los últimos ~10 s, la calidad, la onda con sus latidos y
  la FC, con su historia y los latidos contados sin repetir.
- **La extracción** (`extractor_de_cuadros.dart`, pura): en el dedo, el
  promedio del rojo y de la luminancia Y del centro de la imagen, la
  cobertura (la fracción de puntos rojos y brillantes, como se ve la yema
  con el flash detrás) y la saturación (rojos quemados). En el respaldo del
  rostro (sin ML Kit), la frente y las dos mejillas dentro de un óvalo fijo
  del marco y, de ahí, solo los puntos de **piel** por su color (YCbCr);
  qué puntos son piel se decide cada 15 cuadros.
- **La serie** (`SerieSenal`) separa la extracción del cálculo y se escribe
  como `{metodo, t (ms), canales: {y, r} | {r, g, b}}`.
- **El cálculo** (`dominio/procesamiento_ppg.dart` y `dominio/ppg/`, puro y
  probado): remuestrear a 30 Hz; quitar la tendencia (*smoothness priors*,
  Tarvainen 2002); pasa banda Butterworth de 0,7 a 3,5 Hz (orden 4 por lado,
  de ida y vuelta, biquads propios); recortar artefactos (3,5 desviaciones
  robustas); FC por el pico del espectro (Welch con `fftea`, segmentos de
  12 s con Hann) contrastada con el conteo de picos; calidad (SQI) por la
  prominencia del pico (fundamental y primer armónico sobre la banda), el
  acuerdo entre los dos métodos, la regularidad de los intervalos y, en el
  dedo, la cobertura y la saturación; FR por la línea base y la amplitud de
  los latidos en 0,1–0,5 Hz, solo si la calidad es ≥ 0,6, si la modulación
  es apreciable, si las dos coinciden y si el pico es claro. El rostro pasa
  antes por **POS** (Wang et al., 2017). Con el rojo quemado, el dedo mide
  con la luminancia.
- **El motor** (`MotorSignosCamara`): el de la aplicación es
  `MotorInterno` («interno-ppg v1» en el dedo, «interno-pos v1» en el
  rostro). La interfaz recibe solo la serie de números, así que el cálculo
  se puede cambiar sin tocar las pantallas.
- **El análisis en el servidor (experimental)** (`AnalisisEnServidor`,
  `AnalizadorDeMedicion`): al terminar, si hay red y la serie dura de 10 a
  90 s, se manda la serie a `POST /portal/mediciones/analizar` y se enseña
  el resultado del servidor (`fc`, `fr?`, `vfc?` con SDNN y RMSSD,
  `calidad`, `motor`, `advertencias`), con las mismas reglas de la
  aplicación (sin valor por debajo de 0,3, sin FR por debajo de 0,6). Si
  falla, no hay red o tarda más de 10 s, queda el cálculo del teléfono, y
  la pantalla lo dice. El servidor no guarda nada; lo que se guarda es lo
  que la persona confirma, con su motor en las notas.

### Precisión con señales sintéticas

`test/procesamiento_ppg_test.dart` genera una PPG realista (fundamental con
dos armónicos y variabilidad latido a latido, ~30 cuadros por segundo con
temblor y cuadros perdidos) a 60, 72 y 110 lpm, con 20 semillas por caso:

| Caso | Error máximo de la FC | Calidad mínima |
| --- | --- | --- |
| Limpia | ±0,7 lpm (exigido: ±3) | ≥ 0,7 (buena) |
| Ruido moderado (σ igual a la amplitud del pulso) | ±1,4 lpm (exigido: ±5) | ≥ 0,6 |
| Deriva diez veces el pulso | ±0,7 lpm | ≥ 0,7 |
| Tres movimientos bruscos | ±0,9 lpm (exigido: ±5) | — |
| Señal plana / solo ruido | sin FC | < 0,1 / < 0,4 |

La FR, con respiración a 10, 15 y 20 rpm: ±2 rpm; sin respiración en la
señal (limpia, con ruido o con deriva) nunca se da. POS acierta (±5 lpm)
con una luz que parpadea a 1,6 Hz que engaña al canal verde solo.

### Cómo probarlo en un teléfono (pendiente)

No hubo teléfono para probar la cámara real. Para validarlo (Android e iOS,
en release):

1. Encender el escáner en el panel (Configuración › Telemedicina).
2. **Con un oxímetro de pulso de dedo** en una mano y el teléfono en la
   otra: medir **en reposo** (sentado 5 minutos) y **tras actividad** (dos
   minutos de sentadillas o subir escaleras), cinco veces cada uno, en el
   modo dedo y en el rostro. Anotar la FC del oxímetro al terminar cada
   medición. Lo esperable: en el dedo, dentro de ±5 lpm la mayoría de las
   veces con calidad buena; en el rostro, más dispersión, sobre todo con
   poca luz. Repetir con piel clara y oscura, con luz de día y de noche.
3. Que la calidad baje y aparezca el consejo al: levantar el dedo («Cubre
   bien la cámara…»), apretar fuerte («Apoya el dedo sin apretar»), mover la
   mano o la cabeza («Quédate quieto»), apagar la luz en el modo rostro
   («Busca un lugar con más luz») y sacar la cara del marco («Pon tu cara
   dentro del marco»); que la cuenta arranque sola, se pause y siga.
4. Que el flash se encienda en el modo dedo y **se apague** al terminar,
   cancelar, salir de la pantalla o pasar la aplicación a segundo plano.
5. El permiso: negarlo una vez («Reintentar») y para siempre («Abrir
   ajustes»).
6. Que nada quede en el teléfono: ningún archivo nuevo en la carpeta de la
   aplicación (`adb shell run-as ec.cliniq.sage.app ls -R`) y, con un proxy
   (Charles, mitmproxy), que solo salgan números (el `POST
   /portal/mediciones` y, si hay red, `POST /portal/mediciones/analizar`).
7. En el modo rostro, que **la malla caiga sobre la cara** (si sale
   corrida o al revés, revisar `orientacionDelCuadro`: el giro y el espejo
   de cada plataforma) y que la vista de la cámara y la malla tengan la
   misma proporción (la vista previa y el flujo de imágenes usan la misma
   resolución media). Que ML Kit funcione sin red desde la primera vez y
   que, sin él, se vean solo las esquinas y el barrido.
8. La temperatura del teléfono y la batería en tres mediciones seguidas.
9. La fluidez: que la malla vaya a 60 cuadros por segundo y la cuenta no se
   trabe con la FC en vivo (cada segundo, en el hilo principal: si da
   tirones en un teléfono modesto, pasarla a `Isolate.run`). El tamaño de
   la aplicación con ML Kit (`flutter build apk --analyze-size`).

## Botones de ayuda

Cada pantalla y cada acción que no se entiende sola lleva un **«?»**
(`BotonAyuda(clave: '…')`, en `features/ayuda/presentacion/widgets/`): en
la barra de arriba o, con `enLinea`, junto a la acción. Al tocarlo se abre
una hoja con el título, el texto en Markdown nativo (sus enlaces no sacan
de la aplicación) y, si la hay, **«Ver la guía completa»**, que abre ese
artículo en el centro de ayuda (`CentroAyudaPage(articuloInicial:)`).

- **Los textos los escribe la clínica** en el panel (artículos de ayuda
  con clave) y llegan de `GET /ayuda/contextual`: clave →
  `{titulo, texto, articuloId?}`, solo los de los roles de quien entró y
  con las variables ya sustituidas. **Sin texto para una clave, su botón
  no se enseña**: la aplicación no trae ninguno escrito.
- `AyudaContextualCubit` (en `main.dart`) los carga **una vez por
  sesión** desde el tablero: primero la copia guardada (los «?» aparecen
  desde el primer cuadro, también sin red), después la del servidor. Si
  el servidor no responde, se queda la copia y se reintenta al volver a la
  aplicación. Se guardan por persona en la caché cifrada y se borran al
  cerrar sesión. Una respuesta que no es un mapa no pisa la copia buena.

| Clave | Dónde |
| --- | --- |
| `app.inicio` | Barra del inicio |
| `app.agendar` | Barra de agendar (y de reprogramar) |
| `app.agendar.primerTurno` | Junto a «El primer turno disponible» (paso del médico) |
| `app.agendar.modalidad` | Junto al texto del paso de la modalidad |
| `app.misCitas` | Barra de Mis citas |
| `app.misCitas.reprogramar`, `app.misCitas.cancelar` | Junto a «Reprogramar» y «Cancelar cita» en el detalle de la cita |
| `app.videoconsulta` | Barra de la pantalla de la videoconsulta y junto a «Videoconsulta» en el detalle de la cita |
| `app.consultas`, `app.consultas.nueva` | Barra de Consultas en línea y de la consulta nueva |
| `app.miSalud` | Barra de Mi salud |
| `app.mediciones` | Barra de «Mis signos vitales» |
| `app.escaner` | Barra del escáner experimental |
| `app.miSalud.receta`, `app.miSalud.orden`, `app.miSalud.certificado` | Barra de la receta, la orden y el certificado |
| `app.dependientes`, `app.perfil`, `app.arco`, `app.soporte`, `app.avisos`, `app.ayuda` | Barra de su pantalla |

## Videoconsulta

Las citas de telemedicina ofrecen «Entrar a la videoconsulta» en el detalle
(desde Mis citas y desde la próxima cita) y, el día de la cita, en la propia
tarjeta del inicio; en la lista, la cita con la sala abierta lo dice. El
botón (y la pastilla «Sala abierta») se enciende los minutos antes del
inicio y se apaga los minutos después del fin que dice la configuración
(`telemedicina.minutosAntes`, `minutosDespues`), calculado con la hora
congelada de la cita contra la hora de la clínica y vuelto a mirar cada 30
segundos (`lib/features/citas/dominio/videoconsulta.dart`). El servidor
vuelve a decidir con su 409.

Al tocarlo se pide `GET /portal/citas/:id/videollamada` (dominio, sala,
token firmado y hasta cuándo abre) y la videoconsulta se abre **dentro de la
aplicación, en una ventana sobre la cita**: casi toda la pantalla, con las
esquinas de arriba redondeadas y la cita en penumbra detrás. Arriba, la
cabecera de Cliniq, como la del panel de video web: «Videoconsulta con
<médico>», «Termina a las HH:MM» (el fin de la cita; sin la cita, el cierre
de la sala del servidor menos los minutos de después, en la hora de la
clínica) y colgar. Debajo, la página de Jitsi de la clínica en un WebView
propio (`flutter_inappwebview`). Nunca se sale de la aplicación: ni
navegador, ni pestañas personalizadas, ni una actividad de Jitsi aparte.
Un 409 (la sala todavía no abre o ya cerró) o un 503 (la videoconsulta no
está configurada) no abren la ventana: enseñan el mensaje del servidor bajo
el botón, con el teléfono y el correo de la clínica.

- **Permisos.** Lo primero de la ventana es pedir la cámara y el micrófono
  (`permission_handler`). Sin ellos lo explica, con «Reintentar» o, si el
  teléfono ya no deja preguntar, «Abrir ajustes». El WebView concede la
  cámara y el micrófono solo al servidor de video, sin volver a preguntar;
  el video va dentro de la página (`allowsInlineMediaPlayback`) y suena sin
  tocar nada (`mediaPlaybackRequiresUserGesture: false`).
- **La dirección.** `https://<dominio>/<sala>?jwt=<token>&lang=es#<ajustes>`,
  armada en `dominio/sala_embebida.dart` (`direccionDeLaSala`,
  `ajustesDeJitsi`). Los ajustes son solo claves de las listas blancas de
  Jitsi (`configWhitelist.ts` e `interfaceConfigWhitelist.ts` de
  `stable/jitsi-meet_11248`; las pruebas lo comprueban contra una copia):
  sin enlaces a la aplicación de Jitsi, el asunto «Videoconsulta ·
  <clínica>» (oculto dentro de Jitsi: ya está en la cabecera), «Yo» y
  «Participante» como nombres de respaldo, la barra justa (micrófono,
  cámara, chat, levantar la mano, mosaico, fondo, colgar y ajustes), sin
  invitar, lista de participantes, encuestas, reacciones, grabar,
  transmitir ni las opciones de seguridad, el nombre sin cambiar, sin
  pedidos a terceros, sin la encuesta al colgar, sin «powered by» y
  «Cliniq» donde Jitsi nombraría al proveedor. Lo que Jitsi no acepta desde
  la dirección se resuelve de otra forma: el idioma, con `?lang=es`
  (`defaultLanguage` no está en la lista); las marcas de agua
  (`SHOW_JITSI_WATERMARK`, `SHOW_WATERMARK_FOR_GUESTS`,
  `SHOW_BRAND_WATERMARK`), con un estilo que la aplicación inyecta en la
  página y en el `interface_config.js` del servidor.
- **Sin pantalla previa**, porque el nombre viene en el token: la apaga el
  servidor (`ENABLE_PREJOIN_PAGE=0`), no la dirección. Pedida desde la
  dirección (`prejoinConfig.enabled=false`), Jitsi —cargado solo, sin
  iframe— entraría sin cámara ni micrófono (`disableInitialGUM`).
- **Nunca sale.** Solo se navega a `https://<dominio>/<sala>`
  (`decidirNavegacion`). Otro sitio (jitsi.org, una tienda de aplicaciones,
  otro esquema) no se carga y se sigue en la sala; el mismo servidor en
  otra ruta (la bienvenida, `static/close.html`) es el fin de la sala. Las
  ventanas nuevas no se abren.
- **Al terminar.** Colgar desde Jitsi, que el médico termine la sala o que
  echen a la persona cierra la ventana y vuelve a la cita: el guion escucha
  los eventos de la API de Jitsi, que la página publica en su propia
  ventana porque la dirección trae `jwt` (`video-ready-to-close`, el
  `readyToClose` de la API, y `video-conference-left`), y se los pasa a la
  aplicación. Colgar desde la cabecera o el botón atrás de Android preguntan
  antes («¿Salir de la videoconsulta?»).
- **Si no carga.** Lo dice dentro de la ventana, con «Reintentar». Mientras
  carga, «Conectando con la sala…», hasta que Jitsi avisa que entró (o, con
  la página cargada, ocho segundos, para dejar ver lo que diga la página).
- **El teclado** del chat de Jitsi encoge la sala; la cabecera se queda.

Todo va detrás de interfaces (`ServicioVideollamada`, `PermisosDeVideo` y
`SalaDeVideo`, en `features/citas/data/`; los de verdad son
`VideollamadaEnLaApp`, `PermisosDelSistema` y `SalaJitsi`, el único archivo
que conoce el WebView), así que las pruebas abren la ventana con una sala y
unos permisos de mentira, sin plataforma. Las decisiones del WebView
(navegación, permisos de la página, errores, eventos) son funciones puras.

Los avisos y enlaces a `/portal/videoconsulta/:citaId` abren la pantalla de
la cita —su tarjeta y el botón de siempre— y, si la sala ya está abierta,
la misma ventana encima, sola, una vez; al colgar se vuelve a la cita. Si la
cita no está entre las de la persona, se entra igual y el servidor decide.

## Sin conexión

- La sesión y el perfil van en el **llavero**; la configuración de la
  clínica, sus catálogos y documentos legales, el menú, las citas, las
  consultas en línea (la lista y cada detalle abierto) y los dependientes,
  en una **caché Hive cifrada** con clave en el llavero. Sin red, las
  pantallas abren con lo guardado y dicen desde cuándo.
- `SondeoDeRed` sabe si hay salida: escucha cada petición y, si hace falta,
  pregunta a la raíz de la API, que saluda nombrando a Cliniq (un portal
  cautivo no puede imitarlo). `AvisoSinConexion` lo dice arriba de cada
  pantalla y `ConRed` apaga los botones que necesitan red: agendar,
  cancelar, reprogramar, guardar, enviar una consulta, escribirle al médico
  y entrar a la videoconsulta.
- Durante quince segundos después de una caída, `CorteRapidoSinRed` corta las
  peticiones sin esperar el plazo: la pantalla cae a lo guardado al
  instante.
- Las mediciones registradas sin red quedan en la caché cifrada
  (`mediciones-pendientes:<uid>`), se enseñan como «Pendiente de enviar» y
  salen solas al entrar, al volver a la aplicación y al recuperar la red
  (ver «Mis signos vitales»).
- Los PDF de recetas, órdenes y certificados quedan en la carpeta de
  documentos de la aplicación y se abren sin red (ver «Recetas, órdenes
  y certificados»). Los textos de los botones de ayuda, en la caché
  cifrada, por persona (ver «Botones de ayuda»). El logotipo de la clínica, en la caché cifrada
  con el prefijo `configuracion`.
- Al cerrar sesión se borra lo de la persona (citas, consultas,
  dependientes, el menú, archivos descargados, los PDF, los textos de
  ayuda, recordatorios) y se conservan la configuración, el logotipo, los
  catálogos y los documentos legales, que son de la clínica.

## Recordatorios

`lib/core/notificaciones/recordatorios_citas.dart` programa en el propio
teléfono los avisos que la clínica tenga encendidos para cada cita pendiente
(`agenda.recordatoriosActivos` y, de ellos, `recordatorio24h`,
`recordatorio1h`, `recordatorioInicio`), en la zona de la clínica y con el
nombre de la modalidad y los consejos de sus catálogos. Se reprograman en
cada sincronización —una cita cancelada desde la clínica deja de sonar—, al
agendar, reprogramar o cancelar y cada vez que cambia la configuración (si la
clínica los apaga, se cancelan), y se cancelan todos al cerrar sesión. El permiso se pide ya dentro
de la aplicación, no en el acceso. En la web no hay recordatorios.

## Costuras para lo que falta

Los avisos push (Firebase) y los pagos dependen de un tercero. Cada uno
tiene su interfaz en `lib/core/integraciones/costuras.dart` y una versión
apagada (`PushApagado`, `PagosNoDisponibles`); `Servicios` decide cuál se
usa. Enchufarlos es cambiar esa línea: el cierre de sesión ya llama a
`olvidarEsteTelefono`. La videollamada ya no es una costura: está hecha,
dentro de la aplicación, y su interfaz vive con ella
(`ServicioVideollamada`, en `lib/features/citas/data/videollamada_service.dart`;
ver «Videoconsulta»).

## Icono y arranque

El icono y la pantalla de arranque se generan desde el mismo `CustomPainter`
del logotipo de marca (`PintorLogoCliniq`): un anillo `#5A6E73` con una cruz
`#D16F4B`. Son recursos nativos que se generan al compilar: no cambian con
la configuración de la clínica (dentro de la aplicación, el logotipo y los
colores sí). Tras cambiar el logotipo:

```bash
fvm flutter test tool/generar_iconos_test.dart   # pinta los PNG en assets/images
fvm dart run flutter_launcher_icons              # icono de Android, iOS y web
fvm dart run flutter_native_splash:create        # arranque de Android, iOS y web
```

El icono va sobre un claro cálido (`#F4EFEA`): el anillo gris azulado se
pierde sobre un fondo oscuro. El arranque usa el fondo profundo de la
aplicación y la misma pastilla clara del acceso, para que el paso a la
pantalla de Flutter no se note.

## Pruebas

```bash
fvm flutter analyze   # sin avisos
fvm flutter test
```

| Archivo | Qué fija |
| --- | --- |
| `configuracion_test.dart` | `GET /configuracion/publica`: pública, copia sin red, sin copia no hay valores, lectura estricta, la zona horaria |
| `logo_clinica_test.dart` | `clinica.logo` como dirección absoluta (y el data URL de antes; lo demás, el de marca), bajarlo sin la sesión, la copia de la clínica que sobrevive al cierre de sesión, la dirección nueva, sin red, lo que no es imagen, y cómo se pinta |
| `documentos_pdf_test.dart` | El PDF: la descarga con la sesión, la copia por tipo, id y huella, la orden y su vista previa sin firma (`X-Firma-Estado`), que nunca se hace pasar por la firmada, abrirla sin pedir nada, sin red, la huella que no coincide, lo que no es PDF, la copia dañada, la versión nueva, el borrado al cerrar sesión (también lo temporal), el error del servidor en bytes (y el 409 de la clínica que entrega solo firmado); el visor con dobles: pintar dentro de la aplicación, el aviso de la vista previa, el mensaje del servidor, guardar, compartir, sin conexión y «Reintentar» |
| `catalogos_test.dart` | `GET /catalogos/lote`: todas las claves, elementos completos, lo del servidor manda, copia sin red, sin listas de respaldo, iconos y colores, la espera con «Reintentar» |
| `menu_test.dart` | El menú: aplanado por orden, copia por persona, el enrutador (rutas con parámetros, consulta y fragmento, lo que no es del paciente), la barra, los accesos y la campana, «Muy pronto», externos en la pantalla de páginas web y lo que no se sabe abrir, oculto |
| `legal_test.dart` | `GET /legal/documentos`, títulos y slugs de la API, sin nada escrito |
| `privacidad_test.dart` | ARCO: el servicio y su copia, el detalle y sus límites, vencida, el orden, el plazo en palabras, los derechos activos del catálogo, el plazo de la configuración, la lista, el vacío, el error y la solicitud nueva (y su rechazo) |
| `encuestas_test.dart` | Las pendientes como citas, su copia, responder (comentario, 409), el aviso del inicio y su texto, la encuesta (formulario, no disponible, sin lista, lo que falta, gracias, la siguiente, ya respondida, el error del servidor), la pantalla y el aviso en el tablero |
| `avisos_test.dart` | La campana: el servicio y su copia, el contador (encendido, latidos, en segundo plano, sin red, apagado), la lista (leer, leer todos, borrar y deshacer, ver más), la fecha relativa, la pantalla, «Tu receta está lista» que abre Mi salud y la campana en el tablero según el menú |
| `mi_salud_test.dart` | Mi salud: la lectura (también los certificados de reposo y la firma, en sus dos formas; el número, la modalidad, la cantidad en letras y los signos de alarma de la receta; la firma, el área, las indicaciones clínicas y la preparación de la orden; y los documentos viejos sin nada de eso), los exámenes por área, la atención a distancia, el embarazo, los nombres de los códigos, la copia sin red por persona, el cubit y el documento |
| `mi_salud_page_test.dart` | La pantalla y el detalle de la receta **en dos bloques** («Para la farmacia» y «Cómo tomarlo»), la receta vieja, el aviso de la receta a distancia sin firma, la orden (número, preparación, áreas, firma y su PDF) y el certificado: la firma, «Ver PDF» (desde el documento y desde su fila; sin firma, la vista previa; si el servidor no lo da, su mensaje), el diagnóstico reservado o autorizado, anulado |
| `documentos_legales_test.dart` | El texto de `GET /legal/documentos/:slug`, su copia (también sin sesión) y el 404; el Markdown que se entiende; la pantalla nativa, sus enlaces internos y «Leer» en la aceptación |
| `paleta_marca_test.dart` | Los colores de la marca de la configuración y los de siempre |
| `detalle_cita_test.dart` | Las horas para cambiar, los consejos, la modalidad y el estado de sus catálogos, el contacto |
| `contacto_clinica_test.dart` | Teléfono y correo para tocar, y el número de emergencias |
| `seguridad_test.dart` | La contraseña mínima de la clínica |
| `formulario_dependiente_test.dart` | Parentescos, documento, sexo y sangre de los catálogos; `validarCedula` |
| `fecha_local_test.dart` | La zona se descarta y nunca se convierte; el reloj de la clínica |
| `huecos_test.dart` | La presentación de los turnos: días, mañana, tarde y noche con los cortes de la configuración, anticipación, rechazados y palabras naturales |
| `validaciones_test.dart` | Cédula con módulo 10 (o solo diez dígitos si la clínica lo apaga), pasaporte, fecha no futura, opciones de los catálogos |
| `errores_test.dart` | `{status, message}` con texto o lista, 401 y 423 del acceso, la red |
| `reglas_citas_test.dart` | Las horas para cambiar de la configuración, próximas e historial, cuenta regresiva, consejos del catálogo |
| `recordatorios_test.dart` | Solo los recordatorios encendidos, sus textos de los catálogos, sin avisos vencidos |
| `contrato_api_test.dart` | Lo que se lee y se manda a la API |
| `auth_bloc_test.dart` | Acceso correcto, segundo factor, 401, 423, sesión guardada y vencida, solo pacientes, correo sin confirmar |
| `acceso_pacientes_test.dart` | Quién es paciente, el 403 `CORREO_NO_VERIFICADO` y `POST /auth/registro/reenviar` |
| `agendar_bloc_test.dart` | Especialidades, primer turno disponible, buscador, rejilla desde la API, el 409 al agendar y al reprogramar, sin red y la reprogramación con `excluirCita` |
| `turnos_portal_test.dart` | `GET /portal/proximos-turnos` y `GET /portal/turnos/:doctorId`: lo que se pide y cómo se lee |
| `pasos_agendar_test.dart` | Los pasos de especialidad, médico (con el buscador) y horario, pintados |
| `citas_bloc_test.dart` | La copia sin conexión, cancelar y los recordatorios según la configuración (y cancelados si se apagan) |
| `login_page_test.dart` | La pantalla de acceso con el nombre, el eslogan y el logotipo de la clínica, crear cuenta (el registro de la aplicación, y el correo de vuelta), el personal (la dirección del panel para copiar, sin enlace), el bloqueo, el código y el reenvío con los tiempos de la configuración |
| `registro_test.dart` | Las reglas del registro con los mensajes del panel (nombre, correo, teléfono, documento con `validarCedula`, fecha, contraseña con el mínimo de la clínica y el máximo del API, confirmación), la fortaleza y sus pistas, qué documentos se aceptan al registrarse y cuáles al entrar, lo que se envía, y `RegistroBloc`: documentos, casillas, sin documentos, envío, 409 una vez, doble toque, la espera de la clínica contada a mano y el reenvío |
| `registro_page_test.dart` | La pantalla del registro: los campos y catálogos del panel, lo que falta, cédula y pasaporte, la fortaleza, «Leer» por el enrutador, sin documentos con «Reintentar», el envío de punta a punta con «Revisa tu correo», la espera, «Reenviar enlace» y «Volver a ingresar», y el mensaje del servidor una sola vez |
| `enlaces_de_correo_test.dart` | Qué enlaces abren la aplicación (servidor, https, rutas, ruta base, token), el receptor (abre la pantalla, no la repite, ignora lo demás), confirmar el correo (confirmada, vencido con reenvío, incompleto, sin red) y la contraseña nueva (reglas, guardada, vencida, incompleta) |
| `pagina_web_test.dart` | Las páginas de fuera: qué navegación se carga, va al marcador o al correo, o se bloquea; ventanas nuevas; qué error cuenta; qué dirección se abre y con qué título; la pantalla (cabecera, cerrar, `tel:`, atrás con historial, «Reintentar», «Recargar») |
| `instante_test.dart` | Los instantes reales y la hora de la clínica |
| `archivos_test.dart` | La validación de adjuntos con el tamaño y los tipos de la configuración (WEBP y HEIC por su firma), los nombres y la descarga para abrir un PDF |
| `consultas_servicio_test.dart` | Cada ruta de `/portal/consultas`: método, ruta, cuerpo, el multipart `archivo` y la copia sin red |
| `reglas_consultas_test.dart` | El plazo del médico, qué novedades despiertan al sondeo, el motivo de una cancelación, el formulario dinámico y cómo se leen las respuestas |
| `consultas_bloc_test.dart` | La lista, los borradores y lo que cambia en otras pantallas |
| `nueva_consulta_bloc_test.dart` | Los pasos y su validación, el tope de archivos y de tamaño de la configuración, enviar (borrador → archivos → enviar), reintentar y retomar un borrador con su copia del motivo |
| `detalle_consulta_bloc_test.dart` | Cargar, el sondeo con latidos inyectados (la lista primero, el detalle solo si cambió), escribir con archivo y cancelar |
| `cancelar_consulta_test.dart` | La hoja para cancelar: motivo obligatorio, contador y tope de 500 caracteres |
| `campo_dinamico_test.dart` | Cada tipo de pregunta y el visor de imágenes |
| `videoconsulta_test.dart` | La ventana de la sala de la configuración (y la pastilla «Sala abierta»), pedirla (dominio, sala, token, cierre), los 409/503, la cabecera (médico y hora de fin), el botón, la ventana encima de la cita (la cita sigue debajo; colgar, el botón atrás y Jitsi vuelven a ella), los permisos (reintentar, ajustes), «Conectando…», la sala que no carga con «Reintentar», el teclado, y la pantalla de `/portal/videoconsulta/:citaId` que la abre sola una vez |
| `sala_embebida_test.dart` | La dirección de la sala y los ajustes de Jitsi (solo claves de sus listas blancas, `test/dobles/listas_blancas_jitsi.dart`), lo que se hace con cada navegación, permiso de la página y error del WebView, los eventos de la página y el guion, y cómo quedan la cámara y el micrófono |
| `ayuda_test.dart`, `ayuda_page_test.dart` | El centro de ayuda: el Markdown, la búsqueda (también sin red), las categorías con «Tu guía» primero, los contextuales fuera, el artículo inicial (y el que no está), los enlaces sin salir de la aplicación y `/ayuda?articulo=` |
| `ayuda_contextual_test.dart` | Los botones de ayuda: la lectura de `GET /ayuda/contextual`, la copia por persona (y que una respuesta rota no la pisa), el cubit (la copia y después el servidor, una vez por sesión, sin red, el cierre de sesión, la respuesta tardía de la cuenta anterior) y el `BotonAyuda` **con texto y sin texto** (la hoja, sin guía, sin cubit, cuando llegan los textos y «Ver la guía completa») |
| `botones_de_ayuda_test.dart` | Las claves `app.*` en sus pantallas: el tablero que las carga una vez (y el inicio sin textos), Mi salud y sus documentos, el centro de ayuda y el detalle de la cita |
| `recorrido_app_test.dart` | La aplicación entera contra una API de mentira, también con el texto agrandado |
| `recorrido_consultas_test.dart` | Videoconsulta, consultas en línea de punta a punta y retomar un borrador, también con el texto agrandado |
| `procesamiento_ppg_test.dart` | El procesamiento de la PPG con señales sintéticas: remuestreo, tendencia, el filtro Butterworth (ganancias, fase cero, arranque), el espectro (Welch, Parseval, armónicos, bordes), el conteo de picos, la FC a 60, 72 y 110 lpm limpia, con ruido, deriva y movimientos, la señal plana y el solo ruido (calidad baja), la cobertura y la saturación del dedo, la FR (y que no se invente) y POS |
| `extractor_de_cuadros_test.dart` | De la imagen a los números: YUV420, NV21 y BGRA, la yema, la saturación, la piel del rostro, la rotación del sensor y la serie con su JSON (solo números) |
| `motor_signos_camara_test.dart` | El motor del teléfono (dedo, luminancia, rostro, sin dedo, en vivo y sus consejos), el análisis del servidor (lectura, reglas, con red, falla, plazo, sin red, serie corta) y a dónde se envía al médico |
| `escaner_cubit_test.dart` | El escáner con una fuente falsa: el aviso recordado, sin el modo dedo directo al rostro, medir y guardar, enviar al médico, sin red, el 409 de la cámara apagada, la calidad baja, el permiso, el rostro que arranca solo, se pausa y se pierde, y salir de la aplicación a mitad |
| `escaner_page_test.dart` | Las pantallas del escáner: el aviso con el número de emergencias, el selector (primero el rostro), la medición, el resultado en tarjetas (sin presión ni SpO2, con la tarjeta honesta y el rango), el del servidor, el plan B, enviar al médico, sin la yema y el rostro a pantalla completa |
| `escaner_rostro_test.dart` | El rostro de punta a punta con imágenes sintéticas, el procesador de verdad y un detector falso: las esquinas, el barrido y la malla solo con detección (y sin ML Kit), la guía, el arranque solo y la pausa, la FC en vivo con sus latidos, y el resultado con su detalle y las gráficas (y «No hay suficiente señal…») |
| `rostro_geometria_test.dart` | Punto en polígono, el ajuste que cubre la pantalla, Delaunay (válida, sin solapes y de Delaunay con ~130 puntos, rejillas, repetidos y los contornos de un rostro) y el suavizado |
| `rostro_region_test.dart` | La frente y las mejillas desde los contornos, el promedio de solo la piel en una imagen sintética, el giro y el espejo de cada plataforma, y la conversión desde y hacia ML Kit |
| `procesador_de_rostro_test.dart` | El ritmo de la detección (~10 por segundo, sin bloquear), el promedio en cada cuadro con la última región, la detección vieja y el respaldo por color de piel |
| `guia_encuadre_test.dart` | Cada instrucción de la guía de encuadre, su prioridad y el respaldo sin ML Kit |
| `medicion_en_vivo_test.dart` | La cuenta (arranque solo, parpadeo, pausa sin el hueco, pérdida) y la FC en vivo con una señal sintética a 72 lpm |
| `detalle_medicion_test.dart` | pNN50, SD1, SD2 y el intervalo medio, mínimo y máximo con series de RR conocidas, la limpieza, la FC por segundo, el detalle de una medición y los rangos de referencia para adultos |
| `tendencias_test.dart` | Las tendencias por tipo y periodo, y la pestaña con varios tipos, el cambio de periodo y sin red |
| `mediciones_datos_test.dart` | El modelo, las reglas (rangos, hora, calidad), `/portal/mediciones` (paginación, copia sin red, POST y DELETE) y la cola sin red en la caché |
| `mis_signos_vitales_page_test.dart` | «Mis signos vitales» (las pestañas, insignias, evolución, «?», el escáner según la configuración, borrar, error), «Registrar» (el pulso, la presión, sin red, desde una cita) y el acceso desde la cita |
| `envio_pendientes_test.dart` | Lo registrado sin red sale al entrar y al volver la red |

Las pruebas de blocs nunca esperan un tiempo fijo: esperan el estado que
les interesa, y el sondeo del detalle recibe los latidos de la prueba. La
configuración y los catálogos de prueba están en `test/dobles/clinica.dart`
(`configDePrueba`, `catalogosDePrueba`, `conDatosDeLaClinica`,
`rutasDeLaClinica`), con los valores que antes estaban escritos en la
aplicación; cada prueba de una regla cambia solo el campo que le importa.

No hay SDK de Android ni Xcode en el entorno donde se construyó: además de
las pruebas, `flutter build web` sirve de prueba de compilación.

## Pendientes

- **Probar en teléfonos de verdad**: huella, recordatorios, arranque, icono,
  la cámara (ahora pide permiso la primera vez), la galería, abrir un PDF, la
  pantalla de páginas web, el registro y la videoconsulta (Android e iOS, en
  debug y en release). Ninguna compilación de Android o iOS se ha hecho
  todavía.
- **Enlaces de los correos**: llenar la huella de Android y el Team ID de
  Apple en los archivos `.well-known` del panel y verificar en el teléfono
  (ver «Enlaces de los correos»).
- **Páginas de fuera, en el teléfono**: un enlace externo del menú abre la
  pantalla con su nombre y «Cerrar»; dentro se navega, atrás vuelve y en la
  primera cierra; un `tel:` o `mailto:` de la página abre el marcador o el
  correo; un enlace a otra aplicación (WhatsApp, la tienda) no hace nada; en
  la lista de recientes de Android no aparece ninguna tarea nueva.
- **Recetas, órdenes y certificados, en el teléfono** (Android e iOS, con
  una receta, una orden y un certificado firmados desde el panel, y una
  receta sin firmar para la vista previa):
  - «Ver PDF» abre el PDF dentro de la aplicación, bajo la cabecera de
    Cliniq: ninguna otra aplicación, ni el navegador, ni una tarea nueva en
    las recientes de Android; se amplía con los dedos, se pasa de página y
    con más de una se ve «Página 1 de 2»;
  - en modo avión, el que ya se abrió una vez se vuelve a abrir (con el
    aviso de la copia) y uno que nunca se abrió dice «Sin conexión…» con
    «Reintentar»;
  - «Guardar en el teléfono» abre el diálogo del sistema (Descargas o
    Drive en Android; Archivos en iOS) con el nombre «Receta <código>.pdf»,
    el archivo guardado se abre con el lector del teléfono y conserva la
    firma (Adobe Reader la muestra en el sello);
  - «Compartir» abre la hoja del sistema (WhatsApp, correo) con el mismo
    nombre; en iPad, la hoja sale junto al botón;
  - al cerrar sesión desaparecen `cliniq_documentos/` y, en Android,
    `cache/share_plus`, `cache/pdf_renderer_cache` y
    `cache/cliniq_compartir` (con `adb shell run-as ec.cliniq.sage.app ls`);
  - el aviso «Tu receta está lista» abre Mi salud;
  - el logotipo de la clínica llega por su dirección, sigue después de
    cerrar sesión y en modo avión, y al cambiarlo en el panel se ve el nuevo
    al volver a abrir la aplicación.
- **Videoconsulta, en el teléfono** (Android e iOS, debug y release, con el
  médico entrando desde el panel web):
  - al tocar «Entrar», la ventana se abre encima de la cita y el sistema
    pide la cámara y el micrófono una sola vez; negarlos muestra el aviso
    con «Reintentar», y negarlos para siempre, «Abrir ajustes»;
  - no aparece ningún navegador, pestaña ni pantalla de Jitsi aparte, ni en
    la lista de aplicaciones recientes de Android una tarea nueva;
  - la página sale en español, sin pantalla previa (con el servidor en
    `ENABLE_PREJOIN_PAGE=0`), sin logotipo ni marca de agua de Jitsi, sin
    «powered by» y sin invitación a bajar la aplicación de Jitsi, con el
    asunto oculto y solo los botones de la barra pedidos;
  - al entrar, la cámara y el micrófono están encendidos (el médico ve y
    escucha sin que el paciente toque nada), el video se ve dentro de la
    página y el audio del médico suena por el altavoz o los audífonos;
  - la cabecera dice «Videoconsulta con <médico>» y la hora de fin de la
    cita;
  - colgar en Jitsi, que el médico termine la sala para todos o que eche al
    paciente vuelve a la cita; colgar en la cabecera y el botón atrás de
    Android preguntan antes;
  - un enlace de la página (ayuda, jitsi.org) no abre nada ni saca de la
    sala;
  - el chat de Jitsi: con el teclado abierto, la cabecera sigue a la vista y
    se ve lo que se escribe;
  - sin red o con el servidor caído, el aviso de dentro de la ventana y
    «Reintentar»; con un corte breve, Jitsi se recupera sin cerrar la
    ventana;
  - un aviso o enlace a `/portal/videoconsulta/:citaId` abre la cita con la
    ventana encima;
  - al pasar la aplicación a segundo plano y volver, la sala sigue (iOS
    corta la cámara en segundo plano: se reanuda al volver);
  - en iOS, que el `pod install` tome las macros de `permission_handler`
    (si faltan, la cámara se da por negada sin preguntar).
- **Documentos y ayuda, contra el servidor nuevo**: los endpoints y
  campos del contrato de documentos (`numero`, `modalidad`,
  `signosAlarma`, `cantidadEnLetras`, la firma y los campos nuevos de la
  orden, `GET /portal/ordenes/:id/pdf`, la vista previa con
  `X-Firma-Estado`) y `GET /ayuda/contextual` se programaron contra la
  forma del contrato y se probaron con dobles. Falta probarlos de punta a
  punta cuando el API esté desplegado; con el API de hoy, una receta sin
  firma responde «El PDF de este documento aún no está disponible.» al
  tocar «Ver PDF» y no hay «?» (sin textos).
- **Vigencia de la receta**: el PDF dice «Válida hasta DD/MM/AAAA»; la
  pantalla todavía no, porque el portal no manda la fecha y calcularla
  aquí (`clinico.vigenciaRecetaDias`, que cambia con los antimicrobianos)
  sería inventarla. Tampoco las alergias ni el aviso de receta especial,
  que el portal no manda en la receta.
- **Botones de ayuda, en el teléfono**: que el «?» quepa en la barra de
  cada pantalla junto a la campana y cerrar sesión con el texto
  agrandado, y que la hoja se lea bien con un texto largo.
- **Avisos push y pagos**: enchufar las costuras. Sin push, la respuesta del
  médico a una consulta llega por correo y se ve al abrir la aplicación.
- **El escáner, en el teléfono**: ver «Cómo probarlo en un teléfono» en
  «Escáner experimental» (comparar con un oxímetro de pulso en reposo y
  tras actividad).
- **Mediciones, contra el servidor nuevo**: `/portal/mediciones` y
  `/portal/mediciones/analizar` se programaron contra la forma del
  contrato y se probaron con dobles. Falta probarlos de punta a punta y
  confirmar con el API: la forma de la paginación (se aceptan `page`/`limit`
  y `pagina`/`limite`), la respuesta del `POST` y los umbrales de calidad
  (buena ≥ 0,7, regular ≥ 0,4), que el panel debe pintar igual. Un `POST`
  que llegó al servidor pero cuya respuesta se perdió se reenviará desde la
  cola (el contrato no trae una clave de idempotencia).
- **ML Kit para el rostro**: no se usó (ver «Mis signos vitales y escáner
  experimental» en Dependencias). Si el dueño lo acepta, entra detrás de
  `ExtractorDeRostro`.
- **Mi salud**: los adjuntos de las atenciones cerradas
  (`GET /portal/mi-salud`, sección 6 del contrato de telemedicina) todavía
  no se enseñan; `ArchivoMeta`, el visor y `abrirArchivo` ya sirven para eso.
- **Perfil**: la API deja editar también el embarazo, los antecedentes
  obstétricos, el representante y el tipo de documento; la aplicación
  todavía no los ofrece.
- **Tocar un recordatorio** abre la aplicación, pero todavía no lleva al
  detalle de la cita (el identificador ya viaja en el aviso).
- **Firma de publicación**: falta `android/key.properties` y el almacén.
