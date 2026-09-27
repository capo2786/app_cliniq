// lib/features/encuestas/dominio/reglas_encuesta.dart

/// La encuesta de satisfacción: dos preguntas que se contestan en diez
/// segundos (cómo fue la consulta, de 1 a 5 estrellas, y cuánto recomendaría
/// al médico, de 0 a 10) y un comentario opcional. Los límites son los del
/// API y el panel.
const int puntuacionMaxima = 5;
const int recomendacionMaxima = 10;
const int comentarioEncuestaMaximo = 1000;

/// Qué quiere decir cada puntuación, como en el panel.
const Map<int, String> textoPuntuacion = {
  1: 'Muy mala',
  2: 'Mala',
  3: 'Regular',
  4: 'Buena',
  5: 'Excelente',
};

/// La regla estándar del NPS: de 0 a 6 detractor, 7 y 8 pasivo, 9 y 10
/// promotor. Solo pinta la escala.
enum CategoriaNps { detractor, pasivo, promotor }

CategoriaNps categoriaNps(int valor) {
  if (valor >= 9) return CategoriaNps.promotor;
  if (valor >= 7) return CategoriaNps.pasivo;
  return CategoriaNps.detractor;
}
