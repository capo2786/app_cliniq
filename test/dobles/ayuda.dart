// test/dobles/ayuda.dart

/// Artículos del centro de ayuda con la forma de `GET /ayuda`: las
/// variables `{{…}}` ya vienen reemplazadas por el servidor.
library;

List<Map<String, dynamic>> articulosJson() => [
  {
    '_id': 'a2',
    'titulo': '¿Cómo reprogramo o cancelo una cita?',
    'categoria': 'Citas',
    'contenido':
        'Desde **Mis citas** elige la cita y usa **Cancelar**.\n\n'
        '- Puedes hacerlo hasta 12 horas antes.\n'
        '- Te pediremos el motivo.',
    'orden': 2,
    'publicado': true,
  },
  {
    '_id': 'a1',
    'titulo': '¿Cómo agendo una cita?',
    'categoria': 'Citas',
    'contenido':
        '1. Abre **Agendar cita**.\n2. Elige el médico.\n\n'
        'Si algo falla, [escríbenos](/soporte) o visita '
        '[Clínica Andina](https://andina.ec).',
    'orden': 1,
    'publicado': true,
  },
  {
    '_id': 'a3',
    'titulo': 'Olvidé mi contraseña',
    'categoria': 'Cuenta y acceso',
    'contenido': 'Usa **¿Olvidaste tu contraseña?** en el acceso.',
    'orden': 1,
    'publicado': true,
  },
  {
    '_id': 'a4',
    'titulo': 'Horarios de atención',
    'categoria': '',
    'contenido': 'Llama al 02 255 0000.',
    'orden': 0,
    'publicado': true,
  },
  {
    '_id': 'a5',
    'titulo': 'Lentes y monturas',
    'categoria': 'Ópticas',
    'contenido': 'En la sede norte.',
    'orden': 0,
    'publicado': true,
  },
];
