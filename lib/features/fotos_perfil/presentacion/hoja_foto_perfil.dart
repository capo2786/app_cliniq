// lib/features/fotos_perfil/presentacion/hoja_foto_perfil.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../data/selector_de_foto.dart';
import '../providers/foto_perfil_cubit.dart';
import 'avatar_usuario.dart';

/// De quién es la foto que se cambia.
class DuenioDeFoto {
  final String uid;
  final String nombre;
  final int? fotoVersion;

  /// Es la de quien tiene la sesión (va a `/auth/me/foto`); si no, la de un
  /// dependiente suyo (va a `/auth/:id/foto`).
  final bool propia;

  const DuenioDeFoto({
    required this.uid,
    required this.nombre,
    required this.propia,
    this.fotoVersion,
  });
}

/// Abre la hoja para poner, cambiar o quitar una foto de perfil.
///
/// Devuelve el estado final si se guardó o se quitó, o `null` si se cerró
/// sin cambios.
Future<FotoPerfilState?> mostrarHojaFotoPerfil(
  BuildContext context,
  DuenioDeFoto duenio, {
  FotoPerfilCubit Function()? crearCubit,
}) {
  return showModalBottomSheet<FotoPerfilState>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => BlocProvider(
      create: (_) =>
          crearCubit?.call() ??
          FotoPerfilCubit(
            fotos: Servicios.fotosPerfil,
            selector: Servicios.selectorDeFoto,
            uid: duenio.propia ? null : duenio.uid,
            uidPropio: duenio.propia ? duenio.uid : null,
          ),
      child: HojaFotoPerfil(duenio: duenio),
    ),
  );
}

/// La vista previa y las opciones «Guardar», «Cambiar» y «Quitar».
class HojaFotoPerfil extends StatelessWidget {
  final DuenioDeFoto duenio;

  const HojaFotoPerfil({super.key, required this.duenio});

  static const double _lado = 168;

  Future<void> _cambiar(BuildContext context) async {
    final origen = await showModalBottomSheet<OrigenFoto>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.tarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (contexto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (origen, icono, texto) in _origenes)
              ListTile(
                leading: Icon(icono, color: AppColors.primarioClaro),
                title: Text(
                  texto,
                  style: const TextStyle(color: AppColors.texto),
                ),
                onTap: () => Navigator.of(contexto).pop(origen),
              ),
          ],
        ),
      ),
    );

    if (origen != null && context.mounted) {
      await context.read<FotoPerfilCubit>().elegir(origen);
    }
  }

  Future<void> _quitar(BuildContext context) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: duenio.propia
          ? '¿Quitar tu foto de perfil?'
          : '¿Quitar la foto de ${duenio.nombre}?',
      mensaje: 'En su lugar se verán las iniciales del nombre.',
      confirmar: 'Quitar',
      icono: Icons.hide_image_outlined,
      peligroso: true,
    );

    if (confirmado && context.mounted) {
      await context.read<FotoPerfilCubit>().quitar();
    }
  }

  static const _origenes = [
    (OrigenFoto.camara, Icons.photo_camera_outlined, 'Tomar una foto'),
    (OrigenFoto.galeria, Icons.photo_library_outlined, 'Elegir de la galería'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FotoPerfilCubit, FotoPerfilState>(
      listenWhen: (_, ahora) => ahora.fase == FaseFoto.listo,
      listener: (context, state) => Navigator.of(context).pop(state),
      builder: (context, state) {
        final cubit = context.read<FotoPerfilCubit>();
        final nueva = state.nueva;
        final tieneFoto = duenio.fotoVersion != null;
        final enVistaPrevia =
            nueva != null &&
            (state.fase == FaseFoto.vistaPrevia ||
                state.fase == FaseFoto.guardando);

        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            22,
            14,
            22,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bordeCampo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              duenio.propia
                  ? 'Tu foto de perfil'
                  : 'Foto de perfil de ${duenio.nombre}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              enVistaPrevia
                  ? 'Así se verá. Se recorta en cuadrado, al centro.'
                  : duenio.propia
                  ? 'La ven tus médicos y el personal de la clínica.'
                  : 'La ven sus médicos y el personal de la clínica.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox.square(
                dimension: _lado,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (nueva != null)
                      ClipOval(
                        child: Image.memory(
                          nueva,
                          key: const Key('foto-vista-previa'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      )
                    else
                      AvatarUsuario(
                        uid: duenio.uid,
                        nombre: duenio.nombre,
                        fotoVersion: duenio.fotoVersion,
                        tamano: _lado,
                        degradado: AppGradientes.accion,
                      ),
                    if (state.ocupado)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.veloOvalo,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 14),
              Text(
                state.error!,
                key: const Key('error-foto'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.errorTexto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 22),
            ConRed(
              builder: (context, hayRed) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (enVistaPrevia) ...[
                    BotonPrincipal(
                      texto: 'Guardar',
                      icono: Icons.check_rounded,
                      cargando: state.fase == FaseFoto.guardando,
                      textoCargando: 'Guardando…',
                      onPressed: hayRed && !state.ocupado
                          ? cubit.guardar
                          : null,
                    ),
                    const SizedBox(height: 10),
                    BotonSecundario(
                      texto: 'Cambiar',
                      icono: Icons.flip_camera_ios_outlined,
                      onPressed: state.ocupado ? null : () => _cambiar(context),
                    ),
                  ] else
                    for (final (origen, icono, texto) in _origenes) ...[
                      BotonSecundario(
                        texto: texto,
                        icono: icono,
                        onPressed: state.ocupado
                            ? null
                            : () => cubit.elegir(origen),
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (tieneFoto) ...[
                    if (enVistaPrevia) const SizedBox(height: 10),
                    BotonSecundario(
                      texto: 'Quitar',
                      icono: Icons.hide_image_outlined,
                      color: AppColors.peligroSuave,
                      onPressed: hayRed && !state.ocupado
                          ? () => _quitar(context)
                          : null,
                    ),
                  ],
                  if (!hayRed) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Para guardar o quitar la foto necesitas conexión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.alertaTexto,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
