// lib/features/fotos_perfil/presentacion/avatar_editable.dart

import 'package:flutter/material.dart';

import '../../../core/tema/tokens.dart';
import '../providers/foto_perfil_cubit.dart';
import 'avatar_usuario.dart';
import 'hoja_foto_perfil.dart';

/// El avatar con un botón de cámara: al tocarlo se abre la hoja para poner,
/// cambiar o quitar la foto.
class AvatarEditable extends StatelessWidget {
  final DuenioDeFoto duenio;
  final double tamano;
  final double? radio;
  final Gradient? degradado;
  final Color? fondo;
  final Color colorTexto;
  final BorderSide borde;

  /// Se guardó o se quitó la foto.
  final ValueChanged<FotoPerfilState> alCambiar;

  /// Sin conexión, o mientras otra cosa se guarda, el avatar no se toca.
  final bool habilitado;

  const AvatarEditable({
    super.key,
    required this.duenio,
    required this.alCambiar,
    this.tamano = 86,
    this.radio,
    this.degradado,
    this.fondo,
    this.colorTexto = Colors.white,
    this.borde = BorderSide.none,
    this.habilitado = true,
  });

  Future<void> _abrir(BuildContext context) async {
    final resultado = await mostrarHojaFotoPerfil(context, duenio);
    if (resultado != null) alCambiar(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final insignia = (tamano * 0.34).clamp(20.0, 32.0);

    return Semantics(
      button: true,
      label: duenio.propia
          ? 'Cambiar tu foto de perfil'
          : 'Cambiar la foto de ${duenio.nombre}',
      child: GestureDetector(
        key: Key('avatar-editable-${duenio.uid}'),
        behavior: HitTestBehavior.opaque,
        onTap: habilitado ? () => _abrir(context) : null,
        child: SizedBox.square(
          dimension: tamano,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarUsuario(
                uid: duenio.uid,
                nombre: duenio.nombre,
                fotoVersion: duenio.fotoVersion,
                tamano: tamano,
                radio: radio,
                degradado: degradado,
                fondo: fondo,
                colorTexto: colorTexto,
                borde: borde,
              ),
              if (habilitado)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: insignia,
                    height: insignia,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradientes.accion,
                      border: Border.all(color: AppColors.superficie, width: 2),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: insignia * 0.52,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
