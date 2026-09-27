import 'package:equatable/equatable.dart';

/// Los tipos de pregunta de un motivo de consulta: los mismos de las
/// plantillas clínicas del panel.
enum TipoCampo {
  texto('texto'),
  textoLargo('textoLargo'),
  numero('numero'),
  seleccion('seleccion'),
  siNo('siNo'),
  fecha('fecha');

  /// Como lo escribe la API.
  final String codigo;

  const TipoCampo(this.codigo);

  /// Un tipo que esta versión no conoce se pregunta como texto: es la forma
  /// en que cualquier respuesta cabe.
  static TipoCampo desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().trim();

    return TipoCampo.values.firstWhere(
      (tipo) => tipo.codigo == texto,
      orElse: () => TipoCampo.texto,
    );
  }
}

/// Una pregunta del formulario de un motivo (`CampoFormulario`).
class CampoFormulario extends Equatable {
  final String clave;
  final String etiqueta;
  final TipoCampo tipo;

  /// Solo en `seleccion`.
  final List<String> opciones;

  /// Solo en `numero`: «kg», «°C», «días».
  final String? unidad;

  final bool requerido;

  /// Una explicación corta bajo la pregunta.
  final String? ayuda;

  const CampoFormulario({
    required this.clave,
    required this.etiqueta,
    required this.tipo,
    this.opciones = const [],
    this.unidad,
    this.requerido = false,
    this.ayuda,
  });

  static String? _texto(Object? valor) {
    final t = valor?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  static CampoFormulario? desdeJson(Object? json) {
    if (json is! Map) return null;

    final clave = _texto(json['clave']);
    if (clave == null) return null;

    return CampoFormulario(
      clave: clave,
      etiqueta: _texto(json['etiqueta']) ?? clave,
      tipo: TipoCampo.desdeCodigo(json['tipo']),
      opciones: [
        for (final o in (json['opciones'] as List?) ?? const [])
          if (_texto(o) != null) _texto(o)!,
      ],
      unidad: _texto(json['unidad']),
      requerido: json['requerido'] == true,
      ayuda: _texto(json['ayuda']),
    );
  }

  Map<String, dynamic> aJson() => {
    'clave': clave,
    'etiqueta': etiqueta,
    'tipo': tipo.codigo,
    if (opciones.isNotEmpty) 'opciones': opciones,
    'unidad': ?unidad,
    'requerido': requerido,
    'ayuda': ?ayuda,
  };

  @override
  List<Object?> get props => [
    clave,
    etiqueta,
    tipo,
    opciones,
    unidad,
    requerido,
    ayuda,
  ];
}

/// Lee una lista de campos, saltando los que no tengan clave.
List<CampoFormulario> interpretarCampos(Object? datos) {
  if (datos is! List) return const [];

  return [for (final item in datos) ?CampoFormulario.desdeJson(item)];
}
