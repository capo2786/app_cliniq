// lib/features/perfil/presentacion/perfil_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app/version_instalada.dart';
import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_event.dart';
import '../../dependientes/dominio/validaciones.dart';
import '../../legal/providers/legal_bloc.dart';
import '../../navegacion/dominio/destinos.dart';
import '../../navegacion/presentacion/enrutador.dart';
import '../providers/perfil_cubit.dart';
import 'editar_perfil_page.dart';
import 'widgets/seguridad.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/presentacion/widgets/contacto_clinica.dart';

/// El perfil: datos personales y clínicos, seguridad de la cuenta,
/// documentos aceptados y la salida.
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => PerfilCubit(
            auth: Servicios.auth,
            credenciales: Servicios.credenciales,
            biometria: Servicios.biometria,
          )..cargarBiometria(),
        ),
        BlocProvider(
          create: (_) =>
              LegalBloc(Servicios.legal)..add(const LegalSolicitado()),
        ),
      ],
      child: const _VistaPerfil(),
    );
  }
}

class _VistaPerfil extends StatelessWidget {
  const _VistaPerfil();

  Future<void> _cambiar2fa(BuildContext context, Usuario usuario) async {
    final activar = !usuario.dosFactores;
    final password = await pedirContrasenaPara2fa(context, activar: activar);

    if (password == null || !context.mounted) return;

    await context.read<PerfilCubit>().cambiarDosFactores(
      activo: activar,
      password: password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthBloc>().usuario;

    return BlocListener<PerfilCubit, PerfilState>(
      listenWhen: (antes, ahora) =>
          ahora.operacion != null && antes.operacion != ahora.operacion,
      listener: (context, state) {
        final operacion = state.operacion!;
        final nuevo = operacion.usuario;

        // El perfil cambió: la sesión se entera y lo guarda.
        if (nuevo != null) {
          context.read<AuthBloc>().add(AuthPerfilActualizado(nuevo));
        }

        // Los errores de la contraseña se ven dentro de su hoja.
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          mostrarAviso(context, operacion.mensaje, error: !operacion.exito);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          title: const Text('Mi perfil'),
          actions: const [BotonCerrarSesion(), SizedBox(width: 6)],
        ),
        body: FondoDegradado(
          child: RefreshIndicator(
            color: AppColors.acentoClaro,
            backgroundColor: AppColors.superficie,
            onRefresh: () async {
              context.read<AuthBloc>().add(const AuthPerfilRefrescado());
              context.read<LegalBloc>().add(const LegalSolicitado());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.margenDeScroll(),
              children: usuario == null
                  ? const [CargandoCentro()]
                  : [
                      const AvisoSinConexion(
                        queSePuedeHacer:
                            'Ves los datos guardados en este '
                            'teléfono. Para cambiarlos necesitas conexión.',
                      ),
                      _Identidad(usuario: usuario),
                      const SizedBox(height: 26),
                      const EtiquetaSeccion('Datos personales'),
                      _DatosPersonales(usuario: usuario),
                      const SizedBox(height: 22),
                      const EtiquetaSeccion('Datos clínicos'),
                      _DatosClinicos(usuario: usuario),
                      const SizedBox(height: 16),
                      ConRed(
                        builder: (context, hayRed) => BotonSecundario(
                          texto: 'Editar mis datos',
                          icono: Icons.edit_outlined,
                          color: AppColors.acentoClaro,
                          onPressed: hayRed
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<PerfilCubit>(),
                                      child: EditarPerfilPage(usuario: usuario),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const EtiquetaSeccion('Seguridad'),
                      _Seguridad(
                        usuario: usuario,
                        alCambiar2fa: () => _cambiar2fa(context, usuario),
                      ),
                      const SizedBox(height: 26),
                      const EtiquetaSeccion('Documentos aceptados'),
                      const _DocumentosAceptados(),
                      _DocumentosDeLaClinica(usuario: usuario),
                      const SizedBox(height: 28),
                      BotonSecundario(
                        texto: 'Cerrar sesión',
                        icono: Icons.logout_rounded,
                        color: AppColors.peligroSuave,
                        onPressed: () => confirmarCierreDeSesion(context),
                      ),
                      const SizedBox(height: 22),
                      const PieDeVersion(),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Identidad extends StatelessWidget {
  final Usuario usuario;

  const _Identidad({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradientes.identidad,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primarioClaro.withValues(alpha: 0.24),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.sombraSuave,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradientes.accion,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 3,
              ),
            ),
            child: Text(
              usuario.iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            usuario.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            usuario.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.menta,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    usuario.cedula == null
                        ? 'Paciente de ${context.config.clinica.nombre}'
                        : '${etiquetaDe(context.catalogos, Catalogos.tipoDocumento, usuario.tipoDocumento)} '
                              '${usuario.cedula}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatosPersonales extends StatelessWidget {
  final Usuario usuario;

  const _DatosPersonales({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final nacimiento = deFechaIso(usuario.fechaNacimiento);
    final anios = edad(usuario.fechaNacimiento, Servicios.reloj.hoy());
    final contacto = usuario.contactoEmergencia;

    return TarjetaTranslucida(
      child: Column(
        children: [
          FilaDato(
            icono: Icons.phone_outlined,
            rotulo: 'Teléfono',
            valor: usuario.telefono,
          ),
          FilaDato(
            icono: Icons.cake_outlined,
            rotulo: 'Fecha de nacimiento',
            valor: nacimiento == null
                ? null
                : '${FormatoFecha.corta(nacimiento)}'
                      '${anios == null ? '' : ' · $anios años'}',
          ),
          FilaDato(
            icono: Icons.wc_rounded,
            rotulo: 'Sexo',
            valor: usuario.sexo == null
                ? null
                : etiquetaDe(context.catalogos, Catalogos.sexo, usuario.sexo!),
          ),
          FilaDato(
            icono: Icons.bloodtype_outlined,
            rotulo: 'Tipo de sangre',
            valor: usuario.tipoSangre == null
                ? null
                : etiquetaDe(
                    context.catalogos,
                    Catalogos.tipoSangre,
                    usuario.tipoSangre!,
                  ),
          ),
          FilaDato(
            icono: Icons.home_outlined,
            rotulo: 'Dirección',
            valor: usuario.direccion,
          ),
          FilaDato(
            icono: Icons.contact_emergency_outlined,
            rotulo: 'Contacto de emergencia',
            valor: contacto == null
                ? null
                : [
                    contacto.nombre,
                    if (contacto.parentesco != null) contacto.parentesco!,
                    contacto.telefono,
                  ].join(' · '),
          ),
          const Divider(color: AppColors.bordeCampo, height: 22),
          const ContactoClinica(
            mensaje:
                'El correo y la cédula se cambian en la clínica: son con lo '
                'que se te identifica.',
          ),
        ],
      ),
    );
  }
}

class _DatosClinicos extends StatelessWidget {
  final Usuario usuario;

  const _DatosClinicos({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      child: Column(
        children: [
          FilaDato(
            icono: Icons.warning_amber_rounded,
            rotulo: 'Alergias',
            valor: usuario.alergias,
          ),
          FilaDato(
            icono: Icons.history_edu_rounded,
            rotulo: 'Antecedentes personales',
            valor: usuario.antecedentesPersonales,
          ),
          FilaDato(
            icono: Icons.family_restroom_rounded,
            rotulo: 'Antecedentes familiares',
            valor: usuario.antecedentesFamiliares,
          ),
          FilaDato(
            icono: Icons.self_improvement_rounded,
            rotulo: 'Hábitos',
            valor: usuario.habitos,
          ),
          FilaDato(
            icono: Icons.medication_outlined,
            rotulo: 'Medicación habitual',
            valor: usuario.medicacionHabitual,
          ),
        ],
      ),
    );
  }
}

class _Seguridad extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback alCambiar2fa;

  const _Seguridad({required this.usuario, required this.alCambiar2fa});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerfilCubit, PerfilState>(
      builder: (context, state) => ConRed(
        builder: (context, hayRed) => TarjetaTranslucida(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                enabled: hayRed && !state.guardando,
                leading: Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primarioClaro,
                ),
                title: const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textoSecundario,
                ),
                onTap: () => mostrarCambiarContrasena(context),
              ),
              const Divider(color: AppColors.bordeCampo, height: 1),
              SwitchListTile(
                value: usuario.dosFactores,
                onChanged: hayRed && !state.guardando
                    ? (_) => alCambiar2fa()
                    : null,
                secondary: Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primarioClaro,
                ),
                title: const Text(
                  'Verificación en dos pasos',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Un código a tu correo cada vez que entras.',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
              if (state.biometriaDisponible) ...[
                const Divider(color: AppColors.bordeCampo, height: 1),
                SwitchListTile(
                  value: state.biometriaActiva,
                  onChanged: (valor) =>
                      context.read<PerfilCubit>().cambiarBiometria(valor),
                  secondary: Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.primarioClaro,
                  ),
                  title: const Text(
                    'Entrar con huella o rostro',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Tu contraseña queda cifrada en este teléfono.',
                    style: TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre el texto de un documento legal dentro de la aplicación.
void _leer(BuildContext context, String slug, String titulo) => abrirDestino(
  context,
  DestinoNativo(PantallaNativa.legal, {'slug': slug}),
  titulo: titulo,
);

class _DocumentosAceptados extends StatelessWidget {
  const _DocumentosAceptados();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LegalBloc, LegalState>(
      builder: (context, state) {
        if (state.cargando) {
          return const CargandoCentro(mensaje: 'Cargando documentos…');
        }

        if (state.error != null && state.aceptaciones.isEmpty) {
          return RecuadroAviso.alerta(state.error!);
        }

        if (state.aceptaciones.isEmpty) {
          return const RecuadroAviso.informacion(
            'Todavía no hay documentos aceptados.',
          );
        }

        return TarjetaTranslucida(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final a in state.aceptaciones)
                ListTile(
                  leading: const Icon(
                    Icons.task_alt_rounded,
                    color: AppColors.exito,
                  ),
                  title: Text(
                    a.titulo,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      'Versión ${a.version}',
                      if (a.aceptadoEn != null)
                        'aceptado el ${FormatoFecha.corta(a.aceptadoEn!)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  trailing: a.slug == null
                      ? null
                      : TextButton(
                          onPressed: () => _leer(context, a.slug!, a.titulo),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.acentoSuave,
                          ),
                          child: const Text('Leer'),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Los documentos legales vigentes de la clínica que le aplican a esta
/// cuenta, para leerlos cuando se quiera, dentro de la aplicación. Títulos y
/// nombres cortos salen de `GET /legal/documentos`.
class _DocumentosDeLaClinica extends StatelessWidget {
  final Usuario usuario;

  const _DocumentosDeLaClinica({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LegalBloc, LegalState>(
      builder: (context, state) {
        final documentos = [
          for (final d in state.documentos)
            if (d.aplicaA(tipoDeUsuario: usuario.tipo, roles: usuario.roles)) d,
        ];

        if (documentos.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EtiquetaSeccion('Documentos legales'),
              TarjetaTranslucida(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final d in documentos)
                      ListTile(
                        key: Key('documento-${d.slug}'),
                        leading: Icon(
                          Icons.description_outlined,
                          color: AppColors.primarioClaro,
                        ),
                        title: Text(
                          d.titulo,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: d.version.isEmpty
                            ? null
                            : Text(
                                'Versión ${d.version}',
                                style: const TextStyle(
                                  color: AppColors.textoSecundario,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.acentoSuave,
                        ),
                        onTap: () => _leer(context, d.slug, d.titulo),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
