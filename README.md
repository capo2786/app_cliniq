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

La aplicación consume `https://api-cliniq.gcaicedo-proyectos.com/api`, y los
documentos legales, el registro de pacientes (`/registro`) y el panel del
personal se abren en el panel web, `https://cliniq.gcaicedo-proyectos.com`. Ambas se pueden cambiar al compilar,
sin tocar el código:

```bash
flutter build apk --dart-define=API_URL=https://otro-servidor/api --dart-define=WEB_URL=https://otro-panel
```

La configuración vive en `lib/core/config/entorno.dart`.

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
| Nombre, eslogan y logotipo de la clínica | `GET /configuracion/publica` → `clinica.nombre`, `eslogan`, `logo` (data URL; sin él, el logotipo de marca) | Acceso, arranque, inicio, perfil, legales, cerrar sesión, título |
| Colores de la marca | `clinica.colorPrimario`, `colorAcento` (sin ellos, los tokens de siempre) | El tema entero (`PaletaMarca`) |
| Teléfono y correo | `clinica.telefono`, `correoContacto` | Cada «comunícate con la clínica», para tocar (`tel:`, `mailto:`) |
| Número de emergencias | `clinica.telefonoEmergencia` | Consulta nueva |
| Zona horaria | `clinica.zonaHoraria` | El reloj de la clínica, los instantes y los recordatorios |
| Horas para cancelar o reprogramar | `agenda.horasMinimasCambio` | Detalle de la cita, resumen del agendamiento |
| Recordatorios | `agenda.recordatoriosActivos`, `recordatorio24h`, `recordatorio1h`, `recordatorioInicio` | Se programan solo los encendidos; apagados, se cancelan |
| Rejilla de horarios | `agenda.pasoMinutos`, `minutosAnticipacionReserva`, `diasHorizonteReserva`, `horaInicioTarde`, `horaInicioNoche`, `duracionPresencial/Telemedicina/Asincrona` | Agendar |
| Ventana de la sala de video | `telemedicina.minutosAntes`, `minutosDespues` | Botón de la videoconsulta, «Sala abierta» |
| Consultas en línea | `telemedicina.horasRespuesta`, `diasSeguimiento`, `maxArchivosConsulta` | Textos y tope de archivos |
| Archivos | `archivos.tamanoMaximoMb`, `archivos.tipos` | Selectores y validación antes de subir |
| Seguridad | `seguridad.passwordMinimo`, `bloqueoMinutos`, `otpMinutos`, `resetMinutos`, `reenvioSegundos` | Acceso, código, recuperación, cambiar contraseña |
| Validar la cédula con el módulo 10 | `general.validarCedula` | Dependientes |
| Modalidades (nombre, descripción, color, icono) | `GET /catalogos/lote` → `MODALIDAD_CITA` | Citas, agendar |
| Cómo prepararse | `PREPARACION_CITA` (`<MODALIDAD>_<n>`) | Detalle, próxima cita, agendar, recordatorios |
| Estados de citas y consultas | `ESTADO_CITA`, `ESTADO_CONSULTA` | Pastillas y explicaciones |
| Motivos para cancelar | `MOTIVO_CANCELACION_PACIENTE` | Cancelar una cita |
| Parentescos | `PARENTESCO_DEPENDIENTE` (dependientes), `PARENTESCO` (contacto de emergencia) | Formularios |
| Especialidades y ciudades | `ESPECIALIDAD`, `CIUDAD` | Orden de los filtros de agendar |
| Sexo, documento, tipo de sangre | `SEXO`, `TIPO_DOCUMENTO`, `TIPO_SANGRE` (las etiquetas; los códigos son los de siempre) | Formularios y perfil |
| Documentos legales | `GET /legal/documentos` (clave, slug, versión, título) y `mis-aceptaciones` | Aceptación y perfil; se abren en `https://<web>/legal/<slug>` |
| Menú | `GET /menus/mi-menu?plataforma=APP` | La barra de abajo (4 enlaces + «Perfil») y los accesos rápidos |

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
| `hive_ce_flutter` | Caché cifrada: la configuración, los catálogos, los documentos legales, el menú, las citas y los dependientes para abrir sin conexión |

### Dispositivo y seguridad

| Paquete | Para qué |
| --- | --- |
| `local_auth` | Entrar con huella o rostro |
| `package_info_plus` | Versión instalada, en el pie del acceso y del perfil |
| `url_launcher` | Abrir en el navegador los documentos legales, el registro, el panel web, los enlaces del menú sin pantalla propia y la sala de la videoconsulta; llamar o escribir a la clínica (`tel:`, `mailto:`) |
| `flutter_svg` | Pintar el logotipo de la clínica cuando llega en SVG (`clinica.logo`) |

### Adjuntos de las consultas en línea

| Paquete | Para qué |
| --- | --- |
| `image_picker` | Tomar una foto o elegirla de la galería. La reduce en el propio teléfono (2560 px de lado, calidad 85): de 5–8 MB a menos de uno y medio, sin librerías de imagen en Dart |
| `file_selector` | Elegir un PDF o una imagen guardada (paquete oficial de Flutter, sin permisos) |
| `open_filex` | Abrir un PDF recibido con el visor del teléfono |
| `path_provider` | La carpeta temporal privada donde se guarda ese PDF (se borra al cerrar sesión) |

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
receptor que reprograma los recordatorios tras reiniciar el teléfono. El
identificador es `ec.cliniq.sage.app` y el nombre visible, «Cliniq».

- **Adjuntos sin permisos nuevos.** La cámara se abre con la aplicación de
  cámara del teléfono (intento `IMAGE_CAPTURE`), así que **no** se declara
  `CAMERA`: si se declarara, Android exigiría concederlo antes. La galería
  usa el selector de fotos del sistema y los PDF el de documentos, que solo
  entregan lo elegido.
- `open_filex` trae en su manifiesto `READ_EXTERNAL_STORAGE` y
  `READ_MEDIA_IMAGES/VIDEO/AUDIO`, que la aplicación no usa (los PDF van a
  su carpeta privada) y que Google Play restringe: se quitan con
  `tools:node="remove"`.
- `<queries>` declara lo que se abre fuera: `http`/`https` (navegador,
  videoconsulta), `tel:` y `mailto:` (llamar o escribir a la clínica),
  `IMAGE_CAPTURE` (cámara) y `application/pdf` (visor).

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
(`NSFaceIDUsageDescription`), de la cámara (`NSCameraUsageDescription`) y de
la fototeca (`NSPhotoLibraryUsageDescription`), en español, y solo
orientación vertical en teléfono. El
identificador es `ec.cliniq.sage.app`. El `AppDelegate` se registra como delegado
del centro de notificaciones para que los recordatorios se vean también con
la aplicación abierta.

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
    config/entorno.dart       API_URL, WEB_URL
    configuracion/            la configuración pública de la clínica: modelo, servicio, cubit
    archivos/                 adjuntos: ArchivoMeta, validación antes de subir, selectores y descargas
    fechas/fecha_local.dart   la hora «congelada» de la API y el reloj de la clínica
    fechas/zona_clinica.dart  la zona horaria de la configuración
    fechas/instante.dart      los instantes reales (consultas, mensajes, archivos) en la hora de la clínica
    formato/fechas.dart       cómo se enseñan las fechas
    integraciones/costuras.dart  push, videollamada y pagos: interfaces (la videollamada ya enchufada)
    network/                  ApiClient, interceptores, mensajeDeError
    notificaciones/           recordatorios locales de citas
    presentacion/             márgenes, avisos, enlaces, el observador de rutas, los widgets base,
                              el contacto y el logotipo de la clínica, iconos y colores del servidor
    red/                      el sondeo de la red y el cartel de sin conexión
    storage/                  llavero, credenciales y caché cifrada
    tema/                     tokens, la paleta de la marca y el tema de Material
    servicios.dart            la raíz de composición
  features/
    arranque/                 la espera de los datos de la clínica y de la sesión
    auth/                     acceso, segundo factor, recuperación, sesión
    legal/                    documentos legales de la API y su aceptación
    navegacion/               el menú del servidor y a dónde lleva cada enlace
    inicio/                   el inicio y la barra de pestañas
    citas/                    mis citas, detalle, cancelar, las horas para cambiar y la videoconsulta
    consultas/                consultas en línea: lista, consulta nueva paso a paso y detalle con la conversación
    agendar/                  el agendamiento paso a paso y el cálculo de horarios
    dependientes/             personas a cargo, con la validación de cédula
    perfil/                   datos personales y clínicos, seguridad, documentos
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
   demás. Cada documento tiene su botón «Leer», que abre
   `https://cliniq.gcaicedo-proyectos.com/legal/<slug>` con el slug de la
   API, y su casilla; «Aceptar y continuar»
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
   documentos aceptados con su enlace, los documentos legales vigentes de la
   clínica, cerrar sesión y la versión.
9. **Consultas en línea.** Ver «Consultas en línea».
10. **Recordatorios.** Ver «Recordatorios».
11. **Sin conexión.** Ver «Sin conexión».

La barra de abajo la arma el menú del servidor (`GET
/menus/mi-menu?plataforma=APP`): los cuatro primeros enlaces por su orden,
con el nombre, el icono y el color del administrador, más **Perfil**, que
siempre está; el resto va a los accesos rápidos del inicio. Una ruta que la
aplicación conoce (`/inicio`, `/mis-citas`, `/portal/agendar`,
`/portal/dependientes`, `/portal/consultas`) abre su pantalla; una que no,
`https://<web><ruta>` en el navegador. Agendar va destacado y no cambia de
pestaña: abre el agendamiento encima. El menú se guarda para abrir sin red;
sin copia, un aviso con «Reintentar».

## Pantalla de acceso

Replica la de UCEBell: el logotipo y el nombre de la clínica —sin logotipo
propio, el de marca, el mismo del icono—, su eslogan, la tarjeta
de **vidrio** que desenfoca el fondo, el contenido que **sube al abrir**, cada
campo con su icono en una pastilla y el **anillo de foco terracota**, y un
solo botón con el degradado de la marca. Al pie, la **versión instalada**.

- **«¿Olvidaste tu contraseña?»** pide el enlace con
  `POST /auth/password/olvido`. La API contesta siempre lo mismo, exista o no
  el correo; el enlace abre la página web para crear la contraseña nueva.
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
  el autorregistro del panel web (`/registro`) en el navegador: ahí se
  piden la cédula y los términos y se confirma el correo.
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
  de la clínica usa el panel web: …», con un botón para abrirlo. Lo mismo al
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

## Agendar: cómo se calculan los horarios

`lib/features/agendar/dominio/` es el puerto 1:1 de
`agenda.utils.ts` y `horarios.model.ts` del panel web, con los mismos
nombres: `normalizarHorarios`, `rangosDelDia`, `bloqueoEn`, `duracionDe`,
`margenDe`, `calcularHuecos` (la cita tiene que caber entera en el turno,
margen a ambos lados de cada cita ocupada), `limiteAlcanzado`,
`siguienteDiaConAtencion` y la división en mañana, tarde y noche. De
`agendar.ts` vienen el primer día con atención (hoy solo si todavía cabe una
cita con la anticipación mínima) y la etiqueta de «próxima fecha». El paso de
la rejilla, la anticipación, el horizonte de días, los cortes de la tarde y
la noche y las duraciones por defecto son los de la configuración
(`ReglasAgendamiento`, desde `agenda.*`).

El portal solo recibe lo ocupado del médico (`GET /portal/disponibilidad`,
inicio y fin, nunca datos de otros pacientes). Al reprogramar, el horario de
la propia cita queda libre. El servidor vuelve a validar todo al guardar.

Una diferencia a propósito con el web: el filtro de especialidad ofrece solo
las que tienen al menos un médico, en el orden del catálogo. En un teléfono,
elegir una especialidad sin médicos es un callejón sin salida.

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

Al tocarlo se pide `GET /portal/citas/:id/videollamada` y se abre la `url`
firmada de la sala en el **navegador del teléfono** (`url_launcher`, modo
externo): el navegador ya sabe pedir la cámara y el micrófono, y una nota lo
avisa. Un 409 (la sala todavía no abre o ya cerró) o un 503 (la
videoconsulta no está configurada) enseñan el mensaje del servidor, con el
teléfono y el correo de la clínica.

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
- Al cerrar sesión se borra lo de la persona (citas, consultas,
  dependientes, el menú, archivos descargados, recordatorios) y se conservan
  la configuración, los catálogos y los documentos legales, que son de la
  clínica.

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

Los avisos push (Firebase), la videollamada y los pagos dependen de un
tercero. Cada uno tiene su interfaz en `lib/core/integraciones/costuras.dart`
y una versión apagada (`PushApagado`, `VideollamadaNoDisponible`,
`PagosNoDisponibles`); `Servicios` decide cuál se usa. La videollamada ya
está enchufada: `VideollamadaEnNavegador`
(`lib/features/citas/data/videollamada_service.dart`) pide la sala de Jitsi de
la clínica y la abre en el navegador. Los avisos push y los pagos siguen
apagados; enchufarlos es cambiar esa línea: el cierre de sesión ya llama a
`olvidarEsteTelefono`.

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
| `catalogos_test.dart` | `GET /catalogos/lote`: todas las claves, elementos completos, lo del servidor manda, copia sin red, sin listas de respaldo, iconos y colores, la espera con «Reintentar» |
| `menu_test.dart` | El menú: aplanado por orden, copia por persona, ruta conocida (pantalla) y desconocida (navegador), la barra y los accesos, el tablero |
| `legal_test.dart` | `GET /legal/documentos`, títulos y slugs de la API, sin nada escrito |
| `paleta_marca_test.dart` | Los colores de la marca de la configuración y los de siempre |
| `detalle_cita_test.dart` | Las horas para cambiar, los consejos, la modalidad y el estado de sus catálogos, el contacto |
| `contacto_clinica_test.dart` | Teléfono y correo para tocar, y el número de emergencias |
| `seguridad_test.dart` | La contraseña mínima de la clínica |
| `formulario_dependiente_test.dart` | Parentescos, documento, sexo y sangre de los catálogos; `validarCedula` |
| `fecha_local_test.dart` | La zona se descarta y nunca se convierte; el reloj de la clínica |
| `huecos_test.dart` | El puerto del cálculo de horarios del web, con la rejilla de la configuración |
| `validaciones_test.dart` | Cédula con módulo 10 (o solo diez dígitos si la clínica lo apaga), pasaporte, fecha no futura, opciones de los catálogos |
| `errores_test.dart` | `{status, message}` con texto o lista, 401 y 423 del acceso, la red |
| `reglas_citas_test.dart` | Las horas para cambiar de la configuración, próximas e historial, cuenta regresiva, consejos del catálogo |
| `recordatorios_test.dart` | Solo los recordatorios encendidos, sus textos de los catálogos, sin avisos vencidos |
| `contrato_api_test.dart` | Lo que se lee y se manda a la API |
| `auth_bloc_test.dart` | Acceso correcto, segundo factor, 401, 423, sesión guardada y vencida, solo pacientes, correo sin confirmar |
| `acceso_pacientes_test.dart` | Quién es paciente, el 403 `CORREO_NO_VERIFICADO` y `POST /auth/registro/reenviar` |
| `agendar_bloc_test.dart` | El agendamiento completo, el horario tomado y la reprogramación |
| `citas_bloc_test.dart` | La copia sin conexión, cancelar y los recordatorios según la configuración (y cancelados si se apagan) |
| `login_page_test.dart` | La pantalla de acceso con el nombre, el eslogan y el logotipo de la clínica, crear cuenta, el personal, el bloqueo, el código y el reenvío con los tiempos de la configuración |
| `instante_test.dart` | Los instantes reales y la hora de la clínica |
| `archivos_test.dart` | La validación de adjuntos con el tamaño y los tipos de la configuración (WEBP y HEIC por su firma), los nombres y la descarga para abrir un PDF |
| `consultas_servicio_test.dart` | Cada ruta de `/portal/consultas`: método, ruta, cuerpo, el multipart `archivo` y la copia sin red |
| `reglas_consultas_test.dart` | El plazo del médico, qué novedades despiertan al sondeo, el motivo de una cancelación, el formulario dinámico y cómo se leen las respuestas |
| `consultas_bloc_test.dart` | La lista, los borradores y lo que cambia en otras pantallas |
| `nueva_consulta_bloc_test.dart` | Los pasos y su validación, el tope de archivos y de tamaño de la configuración, enviar (borrador → archivos → enviar), reintentar y retomar un borrador con su copia del motivo |
| `detalle_consulta_bloc_test.dart` | Cargar, el sondeo con latidos inyectados (la lista primero, el detalle solo si cambió), escribir con archivo y cancelar |
| `cancelar_consulta_test.dart` | La hoja para cancelar: motivo obligatorio, contador y tope de 500 caracteres |
| `campo_dinamico_test.dart` | Cada tipo de pregunta y el visor de imágenes |
| `videoconsulta_test.dart` | La ventana de la sala de la configuración (y la pastilla «Sala abierta»), pedirla, abrirla fuera y los 409/503 |
| `recorrido_app_test.dart` | La aplicación entera contra una API de mentira, también con el texto agrandado |
| `recorrido_consultas_test.dart` | Videoconsulta, consultas en línea de punta a punta y retomar un borrador, también con el texto agrandado |

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
  la cámara, la galería, abrir un PDF y la videoconsulta en el navegador.
  Ninguna compilación de Android o iOS se ha hecho todavía.
- **Avisos push y pagos**: enchufar las costuras. Sin push, la respuesta del
  médico a una consulta llega por correo y se ve al abrir la aplicación.
- **Mi salud**: los adjuntos de las atenciones cerradas
  (`GET /portal/mi-salud`, sección 6 del contrato de telemedicina) todavía
  no se enseñan; `ArchivoMeta`, el visor y `abrirArchivo` ya sirven para eso.
- **Perfil**: la API deja editar también el embarazo, los antecedentes
  obstétricos, el representante y el tipo de documento; la aplicación
  todavía no los ofrece.
- **Tocar un recordatorio** abre la aplicación, pero todavía no lleva al
  detalle de la cita (el identificador ya viaja en el aviso).
- **Firma de publicación**: falta `android/key.properties` y el almacén.
