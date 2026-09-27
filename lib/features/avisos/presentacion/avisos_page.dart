// lib/features/avisos/presentacion/avisos_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../navegacion/presentacion/enrutador.dart';
import '../data/avisos_service.dart';
import '../dominio/avisos.dart';
import '../providers/avisos_cubit.dart';
import '../providers/campana_cubit.dart';

/// Los avisos de la campana (`/notificaciones`).
///
/// Al tocar uno queda leído y, si lleva a una pantalla de la aplicación, se
/// abre con el enrutador. Si su enlace no es del paciente (`/admin/...`) se
/// queda aquí: nunca se sale de la aplicación. Deslizarlo lo borra.
/// [titulo] es el nombre que le puso el administrador en el menú.
class AvisosPage extends StatelessWidget {
  final String? titulo;
  final AvisosService? servicio;

  const AvisosPage({super.key, this.titulo, this.servicio});

  static CampanaCubit? _campana(BuildContext context) {
    try {
      return context.read<CampanaCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AvisosCubit(
        servicio ?? Servicios.avisos,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
        campana: _campana(context),
      )..cargar(),
      child: _VistaAvisos(titulo: titulo ?? 'Avisos'),
    );
  }
}

class _VistaAvisos extends StatelessWidget {
  final String titulo;

  const _VistaAvisos({required this.titulo});

  Future<void> _abrir(BuildContext context, Aviso aviso) async {
    final cubit = context.read<AvisosCubit>();
    final marcado = cubit.marcarLeido(aviso);

    final enlace = aviso.enlace;
    if (enlace != null && !abrirRuta(context, enlace)) {
      mostrarAviso(
        context,
        'Este aviso no tiene más detalles en la aplicación.',
      );
    }

    await marcado;
  }

  Future<void> _eliminar(BuildContext context, Aviso aviso) async {
    final borrado = await context.read<AvisosCubit>().eliminar(aviso);

    if (!borrado && context.mounted) {
      mostrarAviso(
        context,
        'No pudimos borrar el aviso. Revisa tu conexión e intenta de nuevo.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvisosCubit, AvisosState>(
      builder: (context, state) {
        final cubit = context.read<AvisosCubit>();
        final error = state.error;
        final ahora = Servicios.reloj.ahora();

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: Text(titulo)),
          body: FondoDegradado(
            child: RefreshIndicator(
              color: AppColors.acentoClaro,
              backgroundColor: AppColors.superficie,
              onRefresh: cubit.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.margenDeScroll(),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer:
                        'Ves los últimos avisos guardados en este teléfono.',
                  ),
                  if (state.cargando && state.avisos.isEmpty)
                    const CargandoCentro(mensaje: 'Buscando tus avisos…')
                  else if (error != null)
                    EstadoError(mensaje: error, alReintentar: cubit.cargar)
                  else if (state.avisos.isEmpty)
                    const EstadoVacio(
                      key: Key('avisos-vacio'),
                      icono: Icons.notifications_none_rounded,
                      titulo: 'Todo al día',
                      descripcion:
                          'No tienes avisos. Aquí te contaremos cuando cambie '
                          'una cita, te responda un médico o haya novedades '
                          'de tus solicitudes.',
                    )
                  else ...[
                    if (state.hayNoLeidos)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ConRed(
                          builder: (context, hayRed) => TextButton.icon(
                            key: const Key('leer-todos'),
                            onPressed: hayRed ? cubit.leerTodos : null,
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text('Marcar todas como leídas'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.acentoSuave,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    for (final aviso in state.avisos) ...[
                      Dismissible(
                        key: ValueKey('borrar-${aviso.id}'),
                        direction: DismissDirection.endToStart,
                        background: const _FondoBorrar(),
                        onDismissed: (_) => _eliminar(context, aviso),
                        child: _TarjetaAviso(
                          aviso: aviso,
                          cuando: tiempoRelativo(aviso.creadaEn, ahora),
                          alTocar: () => _abrir(context, aviso),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (state.hayMas)
                      Center(
                        child: state.cargandoMas
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                ),
                              )
                            : TextButton(
                                key: const Key('ver-mas-avisos'),
                                onPressed: cubit.cargarMas,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.acentoSuave,
                                ),
                                child: const Text('Ver avisos anteriores'),
                              ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Desliza un aviso hacia la izquierda para borrarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoTenue,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  final Aviso aviso;
  final String cuando;
  final VoidCallback alTocar;

  const _TarjetaAviso({
    required this.aviso,
    required this.cuando,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final nuevo = !aviso.leida;
    final color = nuevo ? AppColors.acentoClaro : AppColors.primarioClaro;

    return Semantics(
      label: nuevo ? 'Sin leer' : null,
      child: TarjetaTranslucida(
        key: Key('aviso-${aviso.id}'),
        tinte: nuevo ? AppColors.acento : null,
        onTap: alTocar,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(iconoDeAviso(aviso.tipo), color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          aviso.titulo,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 14,
                            fontWeight: nuevo
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (nuevo)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8, top: 5),
                          decoration: BoxDecoration(
                            color: AppColors.acentoClaro,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aviso.mensaje,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    FormatoFecha.capitalizar(cuando),
                    style: const TextStyle(
                      color: AppColors.textoTenue,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FondoBorrar extends StatelessWidget {
  const _FondoBorrar();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.peligro.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Borrar',
            style: TextStyle(
              color: AppColors.errorTextoClaro,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.delete_outline_rounded, color: AppColors.errorTextoClaro),
        ],
      ),
    );
  }
}
