// lib/features/soporte/dominio/reglas_soporte.dart

import '../../../core/catalogos/catalogo_service.dart';
import '../data/models/ticket.dart';

/*
 * Las reglas de la mesa de ayuda que el servidor valida (auth-ms,
 * soporte.service.ts). Los límites de texto son los suyos: espejan su
 * validación, como el motivo de una cita. Las categorías, los nombres de
 * las severidades y de los estados y las horas de respuesta son de la
 * clínica (catálogos y configuración).
 */

/// El asunto: entre 3 y 150 caracteres.
const int asuntoMinimo = 3;
const int asuntoMaximo = 150;

/// La descripción: entre 10 y 5000 caracteres.
const int descripcionMinima = 10;
const int descripcionMaxima = 5000;

/// Un mensaje: hasta 5000 caracteres.
const int mensajeMaximo = 5000;

/// Las severidades que conoce el sistema, en su orden fijo, y la que el
/// servidor pone si no se manda ninguna.
const List<String> severidadesDelSistema = ['BAJA', 'MEDIA', 'ALTA', 'CRITICA'];
const String severidadPorDefecto = 'MEDIA';

/// La categoría de las consultas médicas: con ella se recuerda que una
/// urgencia no se atiende por aquí (como en el panel).
const String categoriaMedica = 'MEDICO';

/// El texto de un mensaje que solo lleva un archivo, como en el panel.
String textoDeAdjunto(String nombre) => 'Adjunto: $nombre';

/// Por qué no vale el asunto, o `null`. El largo se mide como el servidor
/// (unidades de texto, no letras: un emoji cuenta doble).
String? errorDelAsunto(String asunto) {
  final texto = asunto.trim();
  if (texto.isEmpty) return 'Escribe un asunto.';
  if (texto.length < asuntoMinimo) {
    return 'El asunto debe tener al menos $asuntoMinimo caracteres.';
  }
  if (texto.length > asuntoMaximo) {
    return 'El asunto admite hasta $asuntoMaximo caracteres.';
  }
  return null;
}

/// Por qué no vale la descripción, o `null`.
String? errorDeLaDescripcion(String descripcion) {
  final texto = descripcion.trim();
  if (texto.isEmpty) return 'Cuéntanos qué pasa.';
  if (texto.length < descripcionMinima) {
    return 'Cuéntanos un poco más (al menos $descripcionMinima caracteres).';
  }
  if (texto.length > descripcionMaxima) {
    return 'La descripción admite hasta $descripcionMaxima caracteres.';
  }
  return null;
}

/// Por qué no se puede mandar el mensaje, o `null`. Sin texto vale si lleva
/// un archivo (se manda «Adjunto: …»).
String? errorDelMensaje(String mensaje, {required bool conAdjunto}) {
  final texto = mensaje.trim();
  if (texto.isEmpty && !conAdjunto) return 'Escribe tu mensaje.';
  if (texto.length > mensajeMaximo) {
    return 'El mensaje admite hasta $mensajeMaximo caracteres.';
  }
  return null;
}

/// Las severidades que se ofrecen: las activas de `SEVERIDAD_TICKET`, en su
/// orden. Si el catálogo llega vacío, todas las del sistema (como el panel:
/// el formulario sigue funcionando y la etiqueta es el código).
List<String> severidadesOfrecidas(List<ItemCatalogo> catalogo) {
  final activas = <String>[
    for (final item in catalogo)
      if (severidadesDelSistema.contains(item.codigo.toUpperCase()))
        item.codigo.toUpperCase(),
  ];

  return activas.isEmpty
      ? List.of(severidadesDelSistema)
      : activas.toSet().toList();
}

/// La severidad con que abre el formulario: la del servidor si se ofrece;
/// si no, la primera.
String severidadInicial(List<String> opciones) =>
    opciones.contains(severidadPorDefecto)
    ? severidadPorDefecto
    : (opciones.firstOrNull ?? severidadPorDefecto);

/// La categoría con que abre el formulario: la que la clínica marcó por
/// defecto o, si no hay, la primera. Vacía si el catálogo no tiene ninguna.
String categoriaInicial(List<ItemCatalogo> categorias) =>
    (categorias.where((c) => c.esPorDefecto).firstOrNull ??
            categorias.firstOrNull)
        ?.codigo ??
    '';

/// Los tickets abiertos primero y, dentro, lo más reciente arriba.
List<Ticket> ordenarTickets(Iterable<Ticket> tickets) {
  final lista = tickets.toList();
  final fechaMinima = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  lista.sort((a, b) {
    if (a.estado.atendido != b.estado.atendido) {
      return a.estado.atendido ? 1 : -1;
    }
    return (b.ultimaActividad ?? fechaMinima).compareTo(
      a.ultimaActividad ?? fechaMinima,
    );
  });

  return lista;
}

/// Pone al día (o agrega) un ticket en la lista, y la vuelve a ordenar.
List<Ticket> conTicket(List<Ticket> tickets, Ticket ticket) => ordenarTickets([
  ticket,
  for (final t in tickets)
    if (t.id != ticket.id) t,
]);
