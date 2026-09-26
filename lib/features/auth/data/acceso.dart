/// Cómo se le ofrece entrar a quien abre la aplicación.
enum ModoDeAcceso {
  /// No hay nada guardado en este teléfono: se escribe correo y contraseña.
  primeraVez,

  /// Ya entró, la huella está activa y el teléfono la tiene: entra con eso.
  huella,

  /// Ya entró pero no hay huella disponible o la apagó: se escribe la
  /// contraseña, con el correo ya puesto.
  credencialesGuardadas,
}

/// Las reglas de la pantalla de acceso.
///
/// Están fuera de la pantalla porque deciden algo delicado —qué se rellena
/// solo y cuándo sale la contraseña del llavero— y eso tiene que poder
/// probarse sin levantar una interfaz.
class AccesoRapido {
  const AccesoRapido._();

  static ModoDeAcceso decidir({
    required bool hayCredenciales,
    required bool biometriaDisponible,
    required bool biometriaActiva,
  }) {
    if (!hayCredenciales) return ModoDeAcceso.primeraVez;

    return biometriaDisponible && biometriaActiva
        ? ModoDeAcceso.huella
        : ModoDeAcceso.credencialesGuardadas;
  }

  /// El correo siempre se recuerda: no es un secreto y ahorra escribirlo.
  static bool precargaCorreo(ModoDeAcceso modo) =>
      modo != ModoDeAcceso.primeraVez;

  /// La contraseña nunca se escribe sola en el formulario.
  ///
  /// UCEBell la precarga porque allí hay que poder entrar sin Internet. Aquí
  /// no existe el acceso sin conexión, así que precargarla solo serviría
  /// para que cualquiera con el teléfono en la mano entrara tocando un
  /// botón. La contraseña guardada sale del llavero únicamente después de la
  /// huella.
  static bool precargaContrasena(ModoDeAcceso modo) => false;
}
