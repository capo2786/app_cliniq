// lib/features/mediciones/dominio/reglas_mediciones.dart

import '../data/models/medicion.dart';

/*
 * Las reglas de las mediciones del paciente: los nombres de los códigos del
 * sistema, las unidades, los rangos que acepta el servidor (espejo de sus
 * validadores: el servidor manda y responde 400 si un valor se sale), cómo
 * se enseña un valor y qué se considera calidad buena, regular o baja.
 */

/// El nombre de cada tipo, para la persona.
String nombreDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => 'Pulso',
  TipoMedicion.fr => 'Respiraciones',
  TipoMedicion.pa => 'Presión arterial',
  TipoMedicion.spo2 => 'Saturación de oxígeno',
  TipoMedicion.temp => 'Temperatura',
  TipoMedicion.glucosa => 'Glucosa',
  TipoMedicion.peso => 'Peso',
};

/// El aparato de casa con que se mide cada tipo.
String aparatoDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => 'tensiómetro u oxímetro',
  TipoMedicion.fr => 'contando con el reloj',
  TipoMedicion.pa => 'tensiómetro',
  TipoMedicion.spo2 => 'oxímetro de pulso',
  TipoMedicion.temp => 'termómetro',
  TipoMedicion.glucosa => 'glucómetro',
  TipoMedicion.peso => 'balanza',
};

/// La unidad de cada tipo: la misma que fija el servidor.
String unidadDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => 'lpm',
  TipoMedicion.fr => 'rpm',
  TipoMedicion.pa => 'mmHg',
  TipoMedicion.spo2 => '%',
  TipoMedicion.temp => '°C',
  TipoMedicion.glucosa => 'mg/dL',
  TipoMedicion.peso => 'kg',
};

/// El orden en que se ofrecen los tipos en «Registrar».
const List<TipoMedicion> tiposParaRegistrar = [
  TipoMedicion.pa,
  TipoMedicion.fc,
  TipoMedicion.spo2,
  TipoMedicion.temp,
  TipoMedicion.glucosa,
  TipoMedicion.peso,
  TipoMedicion.fr,
];

/// Un rango cerrado de valores válidos.
class Rango {
  final num minimo;
  final num maximo;

  const Rango(this.minimo, this.maximo);

  bool contiene(num valor) => valor >= minimo && valor <= maximo;
}

/// Los rangos que acepta el servidor (fuera de ellos responde 400).
Rango rangoDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => const Rango(30, 220),
  TipoMedicion.fr => const Rango(6, 60),
  TipoMedicion.pa => const Rango(60, 260),
  TipoMedicion.spo2 => const Rango(70, 100),
  TipoMedicion.temp => const Rango(34, 43),
  TipoMedicion.glucosa => const Rango(20, 600),
  TipoMedicion.peso => const Rango(1, 400),
};

/// La diastólica de la presión.
const Rango rangoDiastolica = Rango(30, 160);

/// Cuántos decimales admite cada tipo al escribirlo.
int decimalesDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.temp || TipoMedicion.peso => 1,
  _ => 0,
};

/// Los métodos que se ofrecen en el formulario: el aparato de casa siempre
/// y, para el pulso y las respiraciones, también contarlos a mano. Los de
/// la cámara salen solo del escáner.
List<MetodoMedicion> metodosDelFormulario(TipoMedicion tipo) => [
  MetodoMedicion.dispositivo,
  if (tipo == TipoMedicion.fc || tipo == TipoMedicion.fr) MetodoMedicion.manual,
];

/// Los contextos que tienen sentido para cada tipo.
List<ContextoMedicion> contextosDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.glucosa => const [
    ContextoMedicion.ayunas,
    ContextoMedicion.posprandial,
  ],
  TipoMedicion.temp || TipoMedicion.peso => const [],
  _ => const [ContextoMedicion.reposo, ContextoMedicion.trasActividad],
};

String nombreDelContexto(ContextoMedicion contexto) => switch (contexto) {
  ContextoMedicion.reposo => 'En reposo',
  ContextoMedicion.trasActividad => 'Tras actividad',
  ContextoMedicion.ayunas => 'En ayunas',
  ContextoMedicion.posprandial => 'Después de comer',
};

String nombreDelMetodo(MetodoMedicion metodo) => switch (metodo) {
  MetodoMedicion.camaraDedo => 'Cámara (dedo) · experimental',
  MetodoMedicion.camaraRostro => 'Cámara (rostro) · experimental',
  MetodoMedicion.dispositivo => 'Aparato de casa',
  MetodoMedicion.manual => 'A mano',
};

/// Lee un número escrito por la persona: acepta la coma decimal («36,8»).
num? leerNumero(String texto) {
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  final numero = num.tryParse(limpio);
  return numero == null || !numero.isFinite ? null : numero;
}

/// «36,8», «78»: el número como se escribe en Ecuador.
String numeroLegible(num valor, {int decimales = 0}) {
  final texto = decimales == 0 && valor == valor.roundToDouble()
      ? valor.round().toString()
      : valor.toStringAsFixed(decimales == 0 ? 1 : decimales);
  return texto.replaceAll('.', ',');
}

String _formatoRango(Rango r, TipoMedicion tipo) =>
    '${numeroLegible(r.minimo)} y ${numeroLegible(r.maximo)} '
    '${unidadDelTipo(tipo)}';

/// Por qué un valor no vale, o `null` si vale. Los mismos rangos y la misma
/// regla de la presión (la sistólica mayor que la diastólica) que el
/// servidor.
String? validarValores(TipoMedicion tipo, num? valor, [num? valor2]) {
  if (valor == null) return 'Escribe el valor.';

  final rango = rangoDelTipo(tipo);
  if (tipo == TipoMedicion.pa) {
    if (!rango.contiene(valor)) {
      return 'La presión sistólica (la alta) debe estar entre '
          '${_formatoRango(rango, tipo)}.';
    }
    if (valor2 == null) return 'Escribe la presión diastólica (la baja).';
    if (!rangoDiastolica.contiene(valor2)) {
      return 'La presión diastólica (la baja) debe estar entre '
          '${_formatoRango(rangoDiastolica, tipo)}.';
    }
    if (valor <= valor2) {
      return 'La sistólica (la alta) debe ser mayor que la diastólica '
          '(la baja).';
    }
    return null;
  }

  if (!rango.contiene(valor)) {
    return '${nombreDelTipo(tipo)}: el valor debe estar entre '
        '${_formatoRango(rango, tipo)}.';
  }
  return null;
}

/// Cuánto hacia atrás se puede registrar (lo que acepta el servidor).
const Duration antiguedadMaxima = Duration(days: 30);

/// La tolerancia hacia el futuro (relojes que no coinciden).
const Duration toleranciaFuturo = Duration(minutes: 5);

/// Por qué la hora de la medición no vale, o `null` si vale.
String? validarMomento(DateTime medidoEn, DateTime ahora) {
  if (medidoEn.isAfter(ahora.add(toleranciaFuturo))) {
    return 'La hora de la medición no puede estar en el futuro.';
  }
  if (medidoEn.isBefore(ahora.subtract(antiguedadMaxima))) {
    return 'Solo se pueden registrar mediciones de los últimos 30 días.';
  }
  return null;
}

/// «78 lpm», «120/80 mmHg», «36,8 °C».
String valorLegible(
  TipoMedicion tipo,
  num valor, {
  num? valor2,
  String? unidad,
}) {
  final decimales = decimalesDelTipo(tipo);
  final numero = tipo == TipoMedicion.pa && valor2 != null
      ? '${numeroLegible(valor)}/${numeroLegible(valor2)}'
      : numeroLegible(valor, decimales: decimales);
  return '$numero ${unidad ?? unidadDelTipo(tipo)}';
}

String valorDeMedicion(Medicion m) =>
    valorLegible(m.tipo, m.valor, valor2: m.valor2, unidad: m.unidad);

String valorDeMedicionNueva(MedicionNueva m) =>
    valorLegible(m.tipo, m.valor, valor2: m.valor2);

/// La calidad de una medición de la cámara, en palabras.
enum NivelCalidad { buena, regular, baja }

/// Desde aquí la calidad es buena.
const double umbralCalidadBuena = 0.7;

/// Desde aquí, regular; por debajo, baja.
const double umbralCalidadRegular = 0.4;

/// Por debajo de esto el escáner no da ningún valor: dice que no pudo medir
/// y ofrece reintentar.
const double calidadMinimaParaMostrar = 0.3;

NivelCalidad nivelDeCalidad(double calidad) => calidad >= umbralCalidadBuena
    ? NivelCalidad.buena
    : calidad >= umbralCalidadRegular
    ? NivelCalidad.regular
    : NivelCalidad.baja;

String nombreDelNivel(NivelCalidad nivel) => switch (nivel) {
  NivelCalidad.buena => 'Calidad buena',
  NivelCalidad.regular => 'Calidad regular',
  NivelCalidad.baja => 'Calidad baja',
};
