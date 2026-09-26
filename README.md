# Cliniq — Aplicación del paciente

Aplicación móvil de Cliniq para pacientes. Quien tiene cuenta en la clínica
agenda sus citas —y las de las personas a su cargo— sin llamar, las cancela o
reprograma con tiempo, recibe recordatorios un día y una hora antes, y ve sus
citas guardadas aunque se quede sin cobertura en la sala de espera.

Consume la API `api-cliniq` (gateway NestJS con prefijo `/api` y JWT) y sigue
las mismas reglas que el panel web `dashboard-cliniq`: los horarios que ofrece
la aplicación salen del mismo cálculo, portado línea a línea.

## Requisitos

| Herramienta | Versión |
| --- | --- |
| Flutter | 3.44.1 (fijada en `.fvmrc`) |
| Dart SDK | ^3.12.1 |
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

La aplicación consume `http://195.7.5.134:3000/api`. La URL se puede cambiar
al compilar, sin tocar el código:

```bash
flutter build apk --dart-define=API_URL=https://api.cliniq.ec/api
```

Los documentos legales se abren en el panel web, que por defecto es
`http://195.7.5.134:4500`; se cambia igual con `--dart-define=WEB_URL=...`.
Sin `--dart-define` se usan los del servidor actual. La configuración vive en
`lib/core/config/entorno.dart`.

### HTTP en claro: temporal

La API todavía responde por **HTTP plano hacia una IP**. Android 9+ e iOS
bloquean eso por defecto, así que hay dos excepciones, **limitadas a
`195.7.5.134`** y a nada más:

- **Android**: `android/app/src/main/res/xml/network_security_config.xml`,
  enlazado desde el `AndroidManifest.xml` con
  `android:networkSecurityConfig`.
- **iOS**: el bloque `NSAppTransportSecurity` de `ios/Runner/Info.plist`.
  Apple advierte que una excepción por IP numérica puede no aplicarse en
  todas las versiones; si en un iPhone la API no responde, esa es la causa, y
  la solución de fondo es la misma de abajo.

**Cuando la API pase a HTTPS con un dominio**, hay que: cambiar `API_URL` y
`WEB_URL` en `entorno.dart`, **borrar** `network_security_config.xml` y su
atributo en el manifiesto, y **borrar** el bloque `NSAppTransportSecurity`.
Ninguna de las dos excepciones debe llegar a una versión que ya use HTTPS.

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
| `hive_ce_flutter` | Caché cifrada: citas, dependientes y catálogos para abrir sin conexión |

### Dispositivo y seguridad

| Paquete | Para qué |
| --- | --- |
| `local_auth` | Entrar con huella o rostro |
| `package_info_plus` | Versión instalada, en el pie del acceso y del perfil |
| `url_launcher` | Abrir los documentos legales en el navegador |

### Fechas y recordatorios

| Paquete | Para qué |
| --- | --- |
| `intl`, `flutter_localizations` | Español en los selectores de fecha del sistema |
| `flutter_local_notifications` ^22.3.0 | Recordatorios 24 h y 1 h antes de cada cita |
| `timezone` | Programa cada aviso en la hora de Ecuador (`America/Guayaquil`) |

Son las mismas versiones que usa UCEBell: por debajo de la 22,
`flutter_local_notifications` arrastra un plugin de Windows con un `xml`
incompatible y `pub get` no resuelve.

### Desarrollo

`flutter_lints`, `bloc_test`, `flutter_launcher_icons`, `flutter_native_splash`.

## Configuración nativa

**Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`,
`USE_BIOMETRIC`, `POST_NOTIFICATIONS` y `RECEIVE_BOOT_COMPLETED`, más el
receptor que reprograma los recordatorios tras reiniciar el teléfono. El
identificador es `ec.cliniq.app` y el nombre visible, «Cliniq».

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

**iOS** (`ios/Runner/Info.plist`): descripción de uso de Face ID, la
excepción de ATS de arriba y solo orientación vertical en teléfono. El
identificador es `ec.cliniq.app`. El `AppDelegate` se registra como delegado
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
- **El estado vive en blocs**; las páginas pintan y despachan eventos. Los
  blocs que comparten las pestañas (sesión, citas, dependientes, catálogos)
  se crean en `main.dart`; una pantalla que se abre por navegación
  (agendar, perfil) crea el suyo para cargar datos frescos en cada visita.
- **El relleno inferior de una lista** sale de `context.margenDeScroll(...)`
  (`lib/core/presentacion/margenes.dart`), que descuenta la barra de
  navegación de Android.
- Los módulos siguen la estructura `features/<modulo>/{data,providers,presentacion}`,
  y las reglas puras de un módulo van en `dominio/`.

### Los colores

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
    catalogos/                MOTIVO_CANCELACION, ESPECIALIDAD, PARENTESCO (con valores de partida)
    config/entorno.dart       API_URL, WEB_URL, zona horaria
    fechas/fecha_local.dart   la hora «congelada» de la API y el reloj de la clínica
    formato/fechas.dart       cómo se enseñan las fechas
    integraciones/costuras.dart  push, videollamada y pagos: interfaces con su versión apagada
    network/                  ApiClient, interceptores, mensajeDeError
    notificaciones/           recordatorios locales de citas
    presentacion/             márgenes, avisos, enlaces y los widgets base
    red/                      el sondeo de la red y el cartel de sin conexión
    storage/                  llavero, credenciales y caché cifrada
    tema/                     tokens y tema de Material
    servicios.dart            la raíz de composición
  features/
    arranque/                 la pantalla mientras se restaura la sesión
    auth/                     acceso, segundo factor, recuperación, sesión
    legal/                    aceptación de documentos
    inicio/                   el inicio y la barra de pestañas
    citas/                    mis citas, detalle, cancelar y la regla de las 12 horas
    agendar/                  el agendamiento paso a paso y el cálculo de horarios
    dependientes/             personas a cargo, con la validación de cédula
    perfil/                   datos personales y clínicos, seguridad, documentos
test/                         pruebas (ver abajo)
tool/generar_iconos_test.dart genera los PNG del icono y del arranque
```

## Pantallas

1. **Arranque.** Mientras se restaura la sesión guardada se ve el logotipo
   sobre el mismo fondo del arranque nativo. La sesión se confirma con
   `GET /auth/me` (con plazo corto): la respuesta trae los documentos legales
   pendientes, y si la clínica publicó una versión nueva hay que pasar por la
   aceptación antes que por el inicio. Sin red se entra igual con el perfil
   guardado.
2. **Acceso.** Ver «Pantalla de acceso».
3. **Aceptación legal.** Si `legalPendientes` no está vacío, bloquea todo lo
   demás. Cada documento tiene su botón «Leer», que abre
   `http://195.7.5.134:4500/legal/<slug>`, y su casilla; «Aceptar y continuar»
   se enciende cuando están todas marcadas, manda `POST /legal/aceptar` y
   relee `/auth/me`. La otra salida es cerrar sesión.
4. **Inicio.** El saludo sobre el degradado de bienvenida; «Tu próxima cita»
   con la hoja de calendario, la hora, el médico, la modalidad, la cuenta
   regresiva y cómo prepararse según la modalidad (presencial: llegar 10
   minutos antes con la cédula y los exámenes; telemedicina: conectarse 5
   minutos antes desde un lugar privado; asíncrona: tener los exámenes a
   mano), y los accesos rápidos a Agendar, Mis citas, Dependientes y Mi
   perfil.
5. **Citas.** Próximas e Historial; las de un dependiente llevan «Para
   <nombre>». El detalle se abre en una hoja inferior con «Reprogramar» (el
   agendamiento en modo reprogramar, con el mismo médico y la misma
   modalidad) y «Cancelar cita» (motivo del catálogo y detalle opcional).
   Con menos de 12 horas por delante, las dos acciones desaparecen y se
   explica por qué.
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
   (catálogo), fecha de nacimiento (no futura), documento (cédula con módulo
   10, o pasaporte), sexo, tipo de sangre y datos clínicos. Quitar pregunta
   antes; con citas pendientes el servidor lo impide y la aplicación lo dice.
8. **Perfil.** Datos personales y clínicos, con edición de lo que la API deja
   cambiar a uno mismo (el correo y la cédula se cambian en la clínica);
   cambiar contraseña, verificación en dos pasos, acceso con huella,
   documentos aceptados con su enlace, cerrar sesión y la versión.
9. **Recordatorios.** Ver «Recordatorios».
10. **Sin conexión.** Ver «Sin conexión».

La barra de abajo tiene Inicio, Citas, **Agendar** (en el centro, destacado),
Dependientes y Perfil. Agendar no cambia de pestaña: abre el agendamiento
encima y al volver se sigue donde se estaba.

## Pantalla de acceso

Replica la de UCEBell: el logotipo de verdad —el mismo del icono—, la tarjeta
de **vidrio** que desenfoca el fondo, el contenido que **sube al abrir**, cada
campo con su icono en una pastilla y el **anillo de foco terracota**, y un
solo botón con el degradado de la marca. Al pie, la **versión instalada**.

- **«¿Olvidaste tu contraseña?»** pide el enlace con
  `POST /auth/password/olvido`. La API contesta siempre lo mismo, exista o no
  el correo; el enlace abre la página web para crear la contraseña nueva.
- **Verificación en dos pasos.** Si la cuenta la tiene, la API contesta
  `{requiere2fa, desafio, destino}` y la misma tarjeta pasa al paso del
  código de seis dígitos (`POST /auth/login/2fa`).
- **Cuenta bloqueada.** Cinco intentos fallidos en quince minutos la cierran
  otros quince (HTTP 423). Se explica con el texto del servidor —que dice
  cuántos minutos faltan— y se ofrece recuperar la contraseña.
- **Sesión vencida.** La API no tiene token de renovación. Un 401 con la
  sesión abierta borra la sesión y lleva al acceso con el aviso «Tu sesión
  venció». Un 401 en las rutas del acceso no es eso: son credenciales o un
  código equivocados.
- **No hay registro público.** Las cuentas las crea la clínica: el acceso
  dice «¿No tienes cuenta? Pide tu registro en la clínica».

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
- `RelojClinica` da la hora de la clínica (UTC−5, Ecuador continental no
  tiene horario de verano) esté donde esté el teléfono: la regla de las 12
  horas y los horarios que ya pasaron se comparan contra la clínica.

Está cubierto por `test/fecha_local_test.dart`.

## Agendar: cómo se calculan los horarios

`lib/features/agendar/dominio/` es el puerto 1:1 de
`agenda.utils.ts` y `horarios.model.ts` del panel web, con los mismos
nombres: `normalizarHorarios`, `rangosDelDia`, `bloqueoEn`, `duracionDe`,
`margenDe`, `calcularHuecos` (paso de 15 minutos, la cita tiene que caber
entera en el turno, margen a ambos lados de cada cita ocupada),
`limiteAlcanzado`, `siguienteDiaConAtencion`, y la división en mañana, tarde
y noche a las 12:00 y a las 19:00. De `agendar.ts` vienen el primer día con
atención (hoy solo si todavía cabe una cita con 15 minutos de anticipación) y
la etiqueta de «próxima fecha».

El portal solo recibe lo ocupado del médico (`GET /portal/disponibilidad`,
inicio y fin, nunca datos de otros pacientes). Al reprogramar, el horario de
la propia cita queda libre. El servidor vuelve a validar todo al guardar.

Una diferencia a propósito con el web: el filtro de especialidad ofrece solo
las que tienen al menos un médico, en el orden del catálogo. En un teléfono,
elegir una especialidad sin médicos es un callejón sin salida.

## Sin conexión

- La sesión y el perfil van en el **llavero**; las citas, los dependientes y
  los catálogos, en una **caché Hive cifrada** con clave en el llavero. Sin
  red, las pantallas abren con lo guardado y dicen desde cuándo.
- `SondeoDeRed` sabe si hay salida: escucha cada petición y, si hace falta,
  pregunta a la raíz de la API, que saluda nombrando a Cliniq (un portal
  cautivo no puede imitarlo). `AvisoSinConexion` lo dice arriba de cada
  pantalla y `ConRed` apaga los botones que necesitan red: agendar,
  cancelar, reprogramar, guardar.
- Durante quince segundos después de una caída, `CorteRapidoSinRed` corta las
  peticiones sin esperar el plazo: la pantalla cae a lo guardado al
  instante.
- Al cerrar sesión se borra lo de la persona (citas, dependientes,
  recordatorios) y se conservan los catálogos, que son de la clínica.

## Recordatorios

`lib/core/notificaciones/recordatorios_citas.dart` programa en el propio
teléfono un aviso **24 horas** y otro **1 hora** antes de cada cita pendiente,
en la zona `America/Guayaquil`. Se reprograman en cada sincronización —una
cita cancelada desde la clínica deja de sonar—, al agendar, reprogramar o
cancelar, y se cancelan todos al cerrar sesión. El permiso se pide ya dentro
de la aplicación, no en el acceso. En la web no hay recordatorios.

## Costuras para lo que falta

Los avisos push (Firebase), la videollamada y los pagos dependen de un
tercero y no entran en esta versión. Cada uno tiene su interfaz en
`lib/core/integraciones/costuras.dart` y una versión apagada
(`PushApagado`, `VideollamadaNoDisponible`, `PagosNoDisponibles`);
`Servicios` decide cuál se usa. Enchufar el de verdad es cambiar esa línea: el
cierre de sesión ya llama a `olvidarEsteTelefono` y el detalle de una cita de
telemedicina ya pregunta si la videollamada está disponible.

## Icono y arranque

El icono y la pantalla de arranque se generan desde el mismo `CustomPainter`
del logotipo (`PintorLogoCliniq`): un anillo `#5A6E73` con una cruz
`#D16F4B`. Tras cambiar el logotipo:

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
| `fecha_local_test.dart` | La zona se descarta y nunca se convierte; el reloj de la clínica |
| `huecos_test.dart` | El puerto del cálculo de horarios del web |
| `validaciones_test.dart` | Cédula con módulo 10, pasaporte, fecha no futura |
| `errores_test.dart` | `{status, message}` con texto o lista, 401 y 423 del acceso, la red |
| `reglas_citas_test.dart` | La regla de las 12 horas, próximas e historial, cuenta regresiva |
| `recordatorios_test.dart` | 24 h y 1 h antes, sin avisos vencidos |
| `contrato_api_test.dart` | Lo que se lee y se manda a la API |
| `auth_bloc_test.dart` | Acceso correcto, segundo factor, 401, 423, sesión guardada y vencida |
| `agendar_bloc_test.dart` | El agendamiento completo, el horario tomado y la reprogramación |
| `citas_bloc_test.dart` | La copia sin conexión y cancelar |
| `login_page_test.dart` | La pantalla de acceso |
| `recorrido_app_test.dart` | La aplicación entera contra una API de mentira, también con el texto agrandado |

No hay SDK de Android ni Xcode en el entorno donde se construyó: además de
las pruebas, `flutter build web` sirve de prueba de compilación.

## Pendientes

- **Probar en teléfonos de verdad**: huella, recordatorios, arranque e icono.
  Ninguna compilación de Android o iOS se ha hecho todavía.
- **HTTPS**: quitar las dos excepciones de tráfico en claro (ver arriba).
- **Avisos push, videollamada y pagos**: enchufar las costuras.
- **Registro de pacientes desde la aplicación**: la API no tiene un endpoint
  público; hoy la clínica crea las cuentas.
- **Perfil**: la API deja editar también el embarazo, los antecedentes
  obstétricos, el representante y el tipo de documento; la aplicación
  todavía no los ofrece.
- **Tocar un recordatorio** abre la aplicación, pero todavía no lleva al
  detalle de la cita (el identificador ya viaja en el aviso).
- **Firma de publicación**: falta `android/key.properties` y el almacén.
