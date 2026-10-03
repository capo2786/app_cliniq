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

/// La guía de usuario del paciente, con la forma nueva de `GET /ayuda`
/// (`clave`, `roles`, `contextual`): el artículo principal lleva la clave
/// `guia.paciente`. El servidor ya la filtra por los roles de quien entra.
List<Map<String, dynamic>> guiaDelPacienteJson() => [
  {
    '_id': 'g2',
    'titulo': 'Cómo ver tus recetas',
    'categoria': 'Guía del paciente',
    'contenido':
        'En **Mi salud**, la parte «Para la farmacia» va a la farmacia.',
    'orden': 1,
    'publicado': true,
    'roles': ['PACIENTE'],
    'clave': '',
    'contextual': false,
  },
  {
    '_id': 'g1',
    'titulo': 'Empieza aquí',
    'categoria': 'Guía del paciente',
    'contenido': 'Todo lo que puedes hacer en la aplicación de Clínica Andina.',
    'orden': 5,
    'publicado': true,
    'roles': ['PACIENTE'],
    'clave': 'guia.paciente',
    'contextual': false,
  },
];

/// Los textos de los botones de ayuda con la forma de
/// `GET /ayuda/contextual`: clave → `{titulo, texto, articuloId?}`.
Map<String, dynamic> ayudaContextualJson() => {
  'app.miSalud': {
    'titulo': 'Mi salud',
    'texto':
        'Aquí ves tus diagnósticos, recetas, órdenes y certificados.\n\n'
        '- La receta tiene **dos partes**.',
    'articuloId': 'g1',
  },
  'app.miSalud.receta': {
    'titulo': 'Tu receta',
    'texto': 'Muestra la parte «Para la farmacia» al retirar tus medicamentos.',
  },
  'app.agendar': {
    'titulo': 'Agendar una cita',
    'texto': 'Elige el médico, la modalidad y la hora.',
    'articuloId': 'g1',
  },
};
