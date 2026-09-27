import '../../../core/fechas/fecha_local.dart';
import '../../../core/fechas/instante.dart';
import '../../../core/formato/fechas.dart';
import '../data/models/campo_formulario.dart';
import '../data/models/consulta.dart';

/// Hasta cuántos caracteres admite la descripción y cada mensaje (los mismos
/// del servidor para los mensajes: 1–4000).
const int maximoDescripcion = 4000;
const int maximoMensaje = 4000;

/// Hasta cuántos caracteres admite el motivo de una cancelación (el mismo
/// tope del servidor, `MOTIVO_CANCELACION_MAX`).
const int maximoMotivoCancelacion = 500;

/// Cuántos archivos se pueden adjuntar a una consulta desde la aplicación.
const int maximoAdjuntos = 10;

/// Horas que tiene el médico para responder (`CONSULTA_HORAS_RESPUESTA`).
const int horasDeRespuesta = 48;

/// Claves de los errores del formulario que no son una pregunta. Llevan un
/// guion bajo delante para no chocar con la clave de ninguna pregunta.
const String claveDescripcion = '_descripcion';
const String claveAdjuntos = '_adjuntos';

// ── Tiempos ──────────────────────────────────────────────────────────

/// Cuánto le queda al médico para responder, en palabras: «Quedan 36 h»,
/// «Queda 1 h», «Quedan 20 min», o «Demorada» si ya pasó el plazo.
///
/// Solo mientras espera respuesta; en cualquier otro estado, `null`. Se
/// calcula con `venceEn` contra el instante de ahora —la pantalla lo pinta
/// entre una consulta al servidor y la siguiente—, y sin `venceEn` se usa
/// `horasRestantes` tal cual lo mandó el servidor.
String? tiempoRestante(ConsultaResumen consulta, DateTime ahora) {
  if (!consulta.estado.esperandoRespuesta) return null;

  final vence = consulta.venceEn;

  if (vence == null) {
    final horas = consulta.horasRestantes;
    if (consulta.vencida) return 'Demorada';
    if (horas == null) return null;
    if (horas <= 0) return 'Queda menos de 1 h';
    return horas == 1 ? 'Queda 1 h' : 'Quedan $horas h';
  }

  if (consulta.vencida || !ahora.toUtc().isBefore(vence)) return 'Demorada';

  final falta = vence.difference(ahora.toUtc());

  if (falta.inHours >= 1) {
    return falta.inHours == 1 ? 'Queda 1 h' : 'Quedan ${falta.inHours} h';
  }

  final minutos = falta.inMinutes < 1 ? 1 : falta.inMinutes;
  return minutos == 1 ? 'Queda 1 min' : 'Quedan $minutos min';
}

/// Si ya pasó el plazo de respuesta.
bool estaDemorada(ConsultaResumen consulta, DateTime ahora) =>
    tiempoRestante(consulta, ahora) == 'Demorada';

/// «Lunes 28 de septiembre, 14:00»: un instante de la API en la hora de la
/// clínica.
String momentoLegible(DateTime instante) {
  final local = enHoraDeLaClinica(instante);
  return '${FormatoFecha.diaLargo(local)}, ${FormatoFecha.hora(local)}';
}

/// «28/09/2026 · 14:00», para los sellos de los mensajes.
String selloLegible(DateTime instante) =>
    FormatoFecha.cortaConHora(enHoraDeLaClinica(instante));

// ── Listas ───────────────────────────────────────────────────────────

List<ConsultaResumen> borradores(List<ConsultaResumen> consultas) =>
    consultas.where((c) => c.estado == EstadoConsulta.borrador).toList();

/// Las que siguen abiertas; primero las que tienen algo por leer.
List<ConsultaResumen> consultasEnCurso(List<ConsultaResumen> consultas) {
  final abiertas = consultas.where((c) => c.estado.enCurso).toList();

  return [
    ...abiertas.where((c) => c.respuestaPorLeer),
    ...abiertas.where((c) => !c.respuestaPorLeer),
  ];
}

List<ConsultaResumen> consultasTerminadas(List<ConsultaResumen> consultas) =>
    consultas.where((c) => c.estado.terminada).toList();

/// Cuántas tienen una respuesta del médico por leer.
int respuestasPorLeer(List<ConsultaResumen> consultas) =>
    consultas.where((c) => c.respuestaPorLeer).length;

/// Si el resumen que acaba de llegar de una consulta dice que cambió algo
/// que no está en [vista]: otro estado, otra cantidad de mensajes u otro
/// último mensaje.
///
/// Decide si hace falta volver a pedir el detalle, que el servidor anota en
/// la bitácora de la historia clínica cada vez que se lee; la lista de
/// resúmenes no se anota.
bool hayNovedades(ConsultaResumen vista, ConsultaResumen nueva) {
  final antes = vista.ultimoMensajeEn;
  final ahora = nueva.ultimoMensajeEn;

  final mismoUltimo = antes == null || ahora == null
      ? antes == ahora
      : antes.isAtSameMomentAs(ahora);

  return nueva.estado != vista.estado ||
      nueva.totalMensajes != vista.totalMensajes ||
      !mismoUltimo;
}

// ── Cancelar ─────────────────────────────────────────────────────────

/// Por qué no vale el motivo de una cancelación, o `null` si vale.
///
/// Se mide como el servidor: sin los espacios de los extremos y contando
/// caracteres como los cuenta él (un emoji puede valer por dos).
String? errorDelMotivoDeCancelacion(String motivo) {
  final texto = motivo.trim();

  if (texto.isEmpty) return 'Cuéntanos por qué la cancelas.';
  if (texto.length > maximoMotivoCancelacion) {
    return 'El motivo admite hasta $maximoMotivoCancelacion caracteres.';
  }

  return null;
}

// ── Formulario ───────────────────────────────────────────────────────

bool valorVacio(Object? valor) =>
    valor == null || (valor is String && valor.trim().isEmpty);

/// Un número escrito con coma o con punto: «37,5» y «37.5» valen lo mismo.
num? numeroDe(Object? valor) {
  if (valor is num) return valor;
  if (valor is! String) return null;

  final texto = valor.trim().replaceAll(',', '.');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(texto)) return null;

  final numero = num.parse(texto);
  return numero == numero.truncate() ? numero.toInt() : numero;
}

/// Por qué una respuesta no vale, o `null` si vale.
String? errorDelCampo(CampoFormulario campo, Object? valor) {
  if (valorVacio(valor)) {
    return campo.requerido ? 'Responde esta pregunta.' : null;
  }

  switch (campo.tipo) {
    case TipoCampo.texto:
    case TipoCampo.textoLargo:
      if (valor.toString().trim().length > maximoDescripcion) {
        return 'La respuesta es demasiado larga.';
      }
    case TipoCampo.numero:
      if (numeroDe(valor) == null) {
        return campo.unidad == null
            ? 'Escribe solo un número.'
            : 'Escribe solo un número (en ${campo.unidad}).';
      }
    case TipoCampo.seleccion:
      if (campo.opciones.isNotEmpty && !campo.opciones.contains(valor)) {
        return 'Elige una de las opciones.';
      }
    case TipoCampo.siNo:
      if (valor is! bool) return 'Elige sí o no.';
    case TipoCampo.fecha:
      if (deFechaIso(valor.toString()) == null) return 'Elige una fecha.';
  }

  return null;
}

/// Todo lo que falta o no vale para poder enviar, por clave.
///
/// Las preguntas van por su clave; la descripción y los adjuntos, por
/// [claveDescripcion] y [claveAdjuntos]. Vacío: se puede enviar.
Map<String, String> erroresDelFormulario({
  required List<CampoFormulario> campos,
  required Map<String, Object?> respuestas,
  required String descripcion,
  required bool requiereAdjunto,
  required int adjuntos,
}) {
  final errores = <String, String>{};

  for (final campo in campos) {
    final error = errorDelCampo(campo, respuestas[campo.clave]);
    if (error != null) errores[campo.clave] = error;
  }

  final texto = descripcion.trim();
  if (texto.isEmpty) {
    errores[claveDescripcion] = 'Cuéntale al médico qué te pasa.';
  } else if (texto.length > maximoDescripcion) {
    errores[claveDescripcion] =
        'La descripción admite hasta $maximoDescripcion caracteres.';
  }

  if (requiereAdjunto && adjuntos == 0) {
    errores[claveAdjuntos] =
        'Este motivo necesita al menos un archivo: una foto o un PDF.';
  }

  return errores;
}

/// Las respuestas como las espera la API: solo las del formulario y cada una
/// con su tipo (texto, número, sí/no o `AAAA-MM-DD`). Al crear se omiten las
/// vacías; al guardar un borrador (`conVacias`) van como `null`, porque el
/// servidor combina con lo guardado y solo así borra una que se vació.
Map<String, Object?> respuestasParaApi(
  List<CampoFormulario> campos,
  Map<String, Object?> respuestas, {
  bool conVacias = false,
}) {
  final resultado = <String, Object?>{};

  for (final campo in campos) {
    final valor = respuestas[campo.clave];
    if (valorVacio(valor)) {
      if (conVacias) resultado[campo.clave] = null;
      continue;
    }

    final convertido = switch (campo.tipo) {
      TipoCampo.texto || TipoCampo.textoLargo => valor.toString().trim(),
      TipoCampo.numero => numeroDe(valor),
      TipoCampo.seleccion => valor.toString(),
      TipoCampo.siNo => valor is bool ? valor : null,
      TipoCampo.fecha => valor.toString().trim(),
    };

    if (convertido != null) resultado[campo.clave] = convertido;
  }

  return resultado;
}

/// Lo que ya se había respondido en un borrador, listo para editarlo: los
/// números vuelven a ser texto, porque se escriben en un campo de texto.
Map<String, Object?> respuestasEditables(List<RespuestaConsulta> respuestas) {
  return {
    for (final r in respuestas)
      if (r.valor != null)
        r.clave: r.tipo == TipoCampo.numero && r.valor is num
            ? numeroLegible(r.valor as num)
            : r.valor,
  };
}

/// «37,5»: los decimales con coma, como se escriben en Ecuador.
String numeroLegible(num numero) {
  final texto = numero == numero.truncate()
      ? numero.toInt().toString()
      : numero.toString();

  return texto.replaceAll('.', ',');
}

/// Una respuesta como se lee: «Sí», «37,5 °C», «28/09/2026».
String valorLegible(TipoCampo tipo, Object? valor, {String? unidad}) {
  if (valorVacio(valor)) return 'Sin respuesta';

  switch (tipo) {
    case TipoCampo.siNo:
      if (valor is bool) return valor ? 'Sí' : 'No';
    case TipoCampo.numero:
      final numero = numeroDe(valor);
      if (numero != null) {
        final texto = numeroLegible(numero);
        return unidad == null ? texto : '$texto $unidad';
      }
    case TipoCampo.fecha:
      final fecha = deFechaIso(valor.toString());
      if (fecha != null) return FormatoFecha.corta(fecha);
    case TipoCampo.texto:
    case TipoCampo.textoLargo:
    case TipoCampo.seleccion:
      break;
  }

  return valor.toString().trim();
}
