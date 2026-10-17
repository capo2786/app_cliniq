// lib/features/clinicas/presentacion/logo_de_clinica_publica.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/entorno.dart';
import '../../../core/tema/contraste.dart';
import '../../../core/tema/tokens.dart';
import '../dominio/clinica.dart';
import '../providers/clinica_cubit.dart';

/// El logotipo de una clínica que todavía no es la de la aplicación: la del
/// código que se acaba de escribir o una de la lista para elegir.
///
/// Sale de su `logoUrl`; sin él, o si no carga, sus iniciales sobre su
/// color primario. (El logotipo de la clínica en uso es `LogoDeLaClinica`,
/// que sale de la configuración y queda guardado en el teléfono.)
class LogoDeClinicaPublica extends StatelessWidget {
  final Clinica clinica;
  final double tamano;

  /// La base para las direcciones relativas; por omisión, la de la API.
  final String api;

  const LogoDeClinicaPublica({
    super.key,
    required this.clinica,
    this.tamano = 48,
    this.api = Entorno.apiUrl,
  });

  @override
  Widget build(BuildContext context) {
    final direccion = direccionDelLogo(clinica, api);
    final iniciales = _Iniciales(clinica: clinica, tamano: tamano);

    return Semantics(
      image: true,
      label: 'Logotipo de ${clinica.nombre}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tamano * 0.28),
          child: SizedBox.square(
            dimension: tamano,
            child: direccion == null
                ? iniciales
                : ColoredBox(
                    color: Colors.white,
                    child: Image.network(
                      direccion.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => iniciales,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Iniciales extends StatelessWidget {
  final Clinica clinica;
  final double tamano;

  const _Iniciales({required this.clinica, required this.tamano});

  @override
  Widget build(BuildContext context) {
    final color = colorHex(clinica.colorPrimario) ?? AppColors.primario;

    return ColoredBox(
      color: color,
      child: Center(
        child: Text(
          clinica.iniciales,
          style: TextStyle(
            color: textoLegibleSobre(color, preferido: Colors.white),
            fontSize: tamano * 0.36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// El [ClinicaCubit] si alguien lo da, o `null`. Las pantallas sueltas de
/// las pruebas no lo dan, y sin él no hay clínica que cambiar.
ClinicaCubit? clinicaCubitSiHay(BuildContext context) {
  try {
    return context.read<ClinicaCubit>();
  } catch (_) {
    return null;
  }
}
