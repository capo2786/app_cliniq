// lib/features/fotos_perfil/presentacion/avatar_usuario.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../data/fotos_perfil_service.dart';
import '../dominio/foto_perfil.dart';

/// La foto de perfil de una persona o, mientras carga, si no tiene o si
/// falla, sus iniciales sobre el color de la marca.
///
/// La foto se pide con el token (`GET /auth/:id/foto?v=`) y se guarda por
/// versión en memoria y en el teléfono ([FotosPerfilService]): solo se
/// descarga la primera vez. Sin [fotoVersion] no se pide nada.
class AvatarUsuario extends StatefulWidget {
  final String uid;
  final String nombre;
  final int? fotoVersion;

  /// El lado del avatar.
  final double tamano;

  /// Radio de las esquinas; sin él, círculo.
  final double? radio;

  /// El fondo de las iniciales: un color ([fondo], que gana) o un
  /// degradado; sin ninguno, el degradado de la marca.
  final Gradient? degradado;
  final Color? fondo;

  final Color colorTexto;
  final BorderSide borde;

  /// Sin él, el de la aplicación (`Servicios.fotosPerfil`).
  final FotosPerfilService? servicio;

  const AvatarUsuario({
    super.key,
    required this.uid,
    required this.nombre,
    this.fotoVersion,
    this.tamano = 48,
    this.radio,
    this.degradado,
    this.fondo,
    this.colorTexto = Colors.white,
    this.borde = BorderSide.none,
    this.servicio,
  });

  @override
  State<AvatarUsuario> createState() => _AvatarUsuarioState();
}

class _AvatarUsuarioState extends State<AvatarUsuario> {
  Uint8List? _bytes;

  /// Cada carga lleva su número: si cambian el uid o la versión mientras
  /// llega la anterior, la vieja no pisa a la nueva.
  int _carga = 0;

  FotosPerfilService get _servicio =>
      widget.servicio ?? Servicios.fotosPerfil;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(AvatarUsuario anterior) {
    super.didUpdateWidget(anterior);

    if (anterior.uid != widget.uid ||
        anterior.fotoVersion != widget.fotoVersion) {
      _cargar();
    }
  }

  void _cargar() {
    final carga = ++_carga;
    final uid = widget.uid;
    final version = widget.fotoVersion;

    if (uid.isEmpty || version == null) {
      _bytes = null;
      return;
    }

    // Ya en memoria: se pinta en el primer cuadro, sin parpadeo.
    _bytes = _servicio.enMemoria(uid, version);
    if (_bytes != null) return;

    _servicio.obtener(uid, version).then((bytes) {
      if (!mounted || carga != _carga) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tamano = widget.tamano;
    final forma = widget.radio == null
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.radio!),
          );
    final bytes = _bytes;

    final iniciales = _Iniciales(
      texto: inicialesDe(widget.nombre),
      tamano: tamano,
      color: widget.colorTexto,
    );

    return Semantics(
      label: widget.nombre.isEmpty ? 'Foto de perfil' : 'Foto de ${widget.nombre}',
      image: true,
      child: Container(
        key: ValueKey('avatar-${widget.uid}'),
        width: tamano,
        height: tamano,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          shape: forma.copyWith(side: widget.borde),
          color: widget.fondo,
          gradient: widget.fondo == null
              ? (widget.degradado ?? AppGradientes.encabezado)
              : null,
        ),
        child: bytes == null
            ? iniciales
            : Image.memory(
                bytes,
                key: const Key('avatar-foto'),
                width: tamano,
                height: tamano,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth:
                    (tamano * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, _, _) => iniciales,
              ),
      ),
    );
  }
}

class _Iniciales extends StatelessWidget {
  final String texto;
  final double tamano;
  final Color color;

  const _Iniciales({
    required this.texto,
    required this.tamano,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        texto,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: color,
          fontSize: tamano * 0.35,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
