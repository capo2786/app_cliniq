// lib/features/privacidad/dominio/reglas_arco.dart

import '../../../core/fechas/fecha_local.dart';
import '../../../core/fechas/instante.dart';
import '../../../core/formato/fechas.dart';
import '../data/arco_service.dart';

/// Los derechos que da la LOPDP, con los códigos del sistema (los que acepta
/// el API). Cuáles se ofrecen, en qué orden y con qué nombre y descripción
/// lo dice el catálogo `TIPO_ARCO`.
const List<String> tiposArco = [
  'ACCESO',
  'RECTIFICACION',
  'ELIMINACION',
  'OPOSICION',
  'PORTABILIDAD',
];

/// El detalle: los mismos límites que el panel y el API (sin espacios en los
/// extremos, como lo cuenta el servidor).
const int detalleArcoMinimo = 10;
const int detalleArcoMaximo = 2000;

/// Qué conviene escribir en el detalle de cada derecho: es ayuda del
/// formulario (la misma del panel), no un dato de la clínica. Lo que es cada
/// derecho viene del catálogo.
const Map<String, String> ayudaTipoArco = {
  'ACCESO':
      'Cuéntanos qué quieres conocer: todos tus datos o algo concreto, como '
      'tus citas o tus datos de contacto.',
  'RECTIFICACION': 'Indica qué dato está mal y cuál es el correcto.',
  'ELIMINACION':
      'Indica qué datos quieres que eliminemos y, si quieres, por qué.',
  'OPOSICION': 'Indica para qué no quieres que usemos tus datos.',
  'PORTABILIDAD':
      'Indica qué datos quieres recibir y, si lo sabes, en qué formato.',
};

/// El error del detalle, o `null` si está bien.
String? validarDetalleArco(String? valor) {
  final texto = valor?.trim() ?? '';

  if (texto.isEmpty) return 'Cuéntanos qué necesitas.';
  if (texto.length < detalleArcoMinimo) {
    return 'Escribe al menos $detalleArcoMinimo caracteres para que podamos '
        'entender tu pedido.';
  }
  if (texto.length > detalleArcoMaximo) {
    return 'Máximo $detalleArcoMaximo caracteres.';
  }

  return null;
}

/// Resuelta o rechazada: ya no corre el plazo.
bool arcoCerrada(SolicitudArco s) =>
    s.estado == 'RESUELTA' || s.estado == 'RECHAZADA';

/// Sigue abierta y ya pasó el plazo legal. Manda lo que dice el servidor; si
/// la copia es vieja, se vuelve a mirar con la hora de ahora.
bool arcoVencida(SolicitudArco s, DateTime ahora) =>
    !arcoCerrada(s) && (s.vencida || s.plazoVence.isBefore(ahora.toUtc()));

/// Las abiertas primero; dentro de cada grupo, la más reciente arriba (como
/// el panel).
List<SolicitudArco> ordenarSolicitudes(List<SolicitudArco> solicitudes) =>
    [...solicitudes]..sort((a, b) {
      final porEstado = (arcoCerrada(a) ? 1 : 0) - (arcoCerrada(b) ? 1 : 0);
      return porEstado != 0 ? porEstado : b.creadaEn.compareTo(a.creadaEn);
    });

/// El plazo de una solicitud abierta, en palabras y en la hora de la
/// clínica: «Respuesta a más tardar el 12 de octubre (en 15 días)», o si ya
/// pasó, «El plazo de respuesta venció el 12 de octubre.». [hoy] es el día
/// de la clínica (`RelojClinica.hoy()`).
String textoPlazoArco(SolicitudArco s, DateTime hoy, {required bool vencida}) {
  final plazo = enHoraDeLaClinica(s.plazoVence);
  final fecha = FormatoFecha.diaYMes(plazo);

  if (vencida) return 'El plazo de respuesta venció el $fecha.';

  final faltan = inicioDelDia(plazo).difference(inicioDelDia(hoy)).inHours;
  final diasQueFaltan = (faltan / 24).round();

  final cuando = switch (diasQueFaltan) {
    <= 0 => 'hoy',
    1 => 'mañana',
    _ => 'en ${dias(diasQueFaltan)}',
  };

  return 'Respuesta a más tardar el $fecha ($cuando).';
}
