// lib/features/ayuda/presentacion/centro_ayuda_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../soporte/presentacion/soporte_page.dart';
import '../data/ayuda_service.dart';
import '../data/models/articulo_ayuda.dart';
import '../dominio/busqueda_ayuda.dart';
import '../dominio/markdown.dart';
import '../providers/ayuda_cubit.dart';
import 'articulo_ayuda_page.dart';
import 'enlaces_de_ayuda.dart';
import 'widgets/acceso_a_soporte.dart';
import 'widgets/buscador_de_ayuda.dart';
import 'widgets/boton_ayuda.dart';

/// El centro de ayuda: «Tu guía» (la guía de usuario de quien entró)
/// primero, buscar, elegir una categoría y leer un artículo.
///
/// La búsqueda la hace el servidor mientras se escribe (con una pausa, para
/// no pedir por cada letra) o al tocar «buscar» en el teclado. Sin conexión
/// se busca en la última copia guardada. Si nada ayuda, el acceso a
/// soporte.
///
/// Con [articuloInicial] (el «Ver la guía completa» de un botón de ayuda, o
/// `/ayuda?articulo=<id>`), abre ese artículo en cuanto llega la lista.
class CentroAyudaPage extends StatelessWidget {
  /// Por defecto, `Servicios.ayuda`.
  final AyudaService? servicio;

  /// Para abrir con el enrutador de la aplicación los enlaces de los
  /// artículos que llevan a otros módulos (`/portal/agendar`…). Sin él,
  /// esos enlaces avisan que la sección no está disponible.
  final AbrirRutaInterna? abrirRuta;

  /// El identificador del artículo que se abre al llegar.
  final String? articuloInicial;

  const CentroAyudaPage({
    super.key,
    this.servicio,
    this.abrirRuta,
    this.articuloInicial,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = articuloInicial?.trim() ?? '';

    return BlocProvider(
      create: (_) => AyudaCubit(
        servicio: servicio ?? Servicios.ayuda,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
      )..buscar(),
      child: inicial.isEmpty
          ? _VistaAyuda(abrirRuta: abrirRuta)
          : _AbrirArticuloInicial(
              id: inicial,
              abrirRuta: abrirRuta,
              child: _VistaAyuda(abrirRuta: abrirRuta),
            ),
    );
  }
}

/// Abre el artículo [id] la primera vez que llega la lista (del servidor o
/// de la copia). Si no está —no es para quien entró, o ya no existe—, lo
/// dice y se queda en el centro.
class _AbrirArticuloInicial extends StatefulWidget {
  final String id;
  final AbrirRutaInterna? abrirRuta;
  final Widget child;

  const _AbrirArticuloInicial({
    required this.id,
    required this.abrirRuta,
    required this.child,
  });

  @override
  State<_AbrirArticuloInicial> createState() => _AbrirArticuloInicialState();
}

class _AbrirArticuloInicialState extends State<_AbrirArticuloInicial> {
  bool _hecho = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AyudaCubit, AyudaState>(
      listenWhen: (_, ahora) => !_hecho && ahora.carga == CargaAyuda.lista,
      listener: (context, state) {
        _hecho = true;
        final articulo = state.articulos
            .where((a) => a.id == widget.id)
            .firstOrNull;

        if (articulo == null) {
          mostrarAviso(
            context,
            'No encontramos esa guía en el centro de ayuda.',
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArticuloAyudaPage(
              articulo: articulo,
              abrirRuta: widget.abrirRuta,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _VistaAyuda extends StatelessWidget {
  final AbrirRutaInterna? abrirRuta;

  const _VistaAyuda({required this.abrirRuta});

  void _abrir(BuildContext context, ArticuloAyuda articulo) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ArticuloAyudaPage(articulo: articulo, abrirRuta: abrirRuta),
        ),
      );

  void _irASoporte(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SoportePage()));

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AyudaCubit>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Centro de ayuda'),
        actions: const [
          BotonAyuda(clave: 'app.ayuda'),
          BotonCerrarSesion(),
          SizedBox(width: 6),
        ],
      ),
      body: FondoDegradado(
        child: BlocBuilder<AyudaCubit, AyudaState>(
          builder: (context, state) => RefreshIndicator(
            color: AppColors.acentoClaro,
            backgroundColor: AppColors.superficie,
            onRefresh: cubit.reintentar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: context.margenDeScroll(inferior: 28),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Buscamos en los artículos que guardamos en este '
                      'teléfono.',
                ),
                BuscadorDeAyuda(alBuscar: cubit.buscar),
                const SizedBox(height: 18),
                if (state.desdeCache && state.guardadaEn != null) ...[
                  RecuadroAviso.informacion(
                    'Mostramos los artículos guardados el '
                    '${FormatoFecha.cortaConHora(state.guardadaEn!)}.',
                    icono: Icons.offline_pin_outlined,
                  ),
                  const SizedBox(height: 12),
                ],
                ..._resultados(context, state),
                const SizedBox(height: 22),
                AccesoASoporte(
                  key: const Key('acceso-soporte-centro'),
                  titulo: '¿No encontraste lo que buscabas?',
                  descripcion:
                      'Escríbenos: te responde una persona del equipo de '
                      'soporte.',
                  accion: 'Ir a soporte',
                  alTocar: () => _irASoporte(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resultados(BuildContext context, AyudaState state) {
    final cubit = context.read<AyudaCubit>();

    if (state.carga == CargaAyuda.error) {
      return [
        EstadoError(
          mensaje: state.error ?? 'No pudimos cargar la ayuda.',
          alReintentar: cubit.reintentar,
        ),
      ];
    }

    if (state.articulos.isEmpty) {
      if (state.carga != CargaAyuda.lista) {
        return const [CargandoCentro(mensaje: 'Buscando…')];
      }

      final buscado = state.busqueda.isNotEmpty;
      return [
        EstadoVacio(
          icono: Icons.search_off_rounded,
          titulo: buscado
              ? 'No encontramos artículos'
              : 'Todavía no hay artículos',
          descripcion: buscado
              ? 'Prueba con otras palabras, por ejemplo «cita», «contraseña» '
                    'o «pago».'
              : 'Pronto publicaremos guías para resolver las dudas más '
                    'comunes.',
        ),
      ];
    }

    final grupos = state.grupos;

    return [
      if (grupos.length > 1) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChipDeOpcion(
              key: const Key('categoria-todas'),
              texto: 'Todas',
              cantidad: state.articulos.length,
              elegido: state.categoria.isEmpty,
              onTap: () => cubit.elegirCategoria(''),
            ),
            for (final grupo in grupos)
              ChipDeOpcion(
                key: Key('categoria-${grupo.categoria}'),
                texto: grupo.categoria,
                cantidad: grupo.articulos.length,
                elegido: state.categoria == grupo.categoria,
                onTap: () => cubit.elegirCategoria(grupo.categoria),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],
      for (final grupo in state.visibles) ...[
        EtiquetaSeccion(
          grupo.esGuia ? 'Tu guía · ${grupo.categoria}' : grupo.categoria,
        ),
        _Grupo(
          key: grupo.esGuia ? Key('tu-guia-${grupo.categoria}') : null,
          grupo: grupo,
          alAbrir: (a) => _abrir(context, a),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }
}

/// Los artículos de una categoría, en una tarjeta. La de una guía de
/// usuario va teñida y con su artículo principal destacado.
class _Grupo extends StatelessWidget {
  final GrupoDeArticulos grupo;
  final void Function(ArticuloAyuda articulo) alAbrir;

  const _Grupo({super.key, required this.grupo, required this.alAbrir});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      padding: EdgeInsets.zero,
      tinte: grupo.esGuia ? AppColors.acentoClaro : null,
      child: Column(
        children: [
          for (final (i, articulo) in grupo.articulos.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.bordeCampo),
            _FilaArticulo(articulo: articulo, alTocar: () => alAbrir(articulo)),
          ],
        ],
      ),
    );
  }
}

class _FilaArticulo extends StatelessWidget {
  final ArticuloAyuda articulo;
  final VoidCallback alTocar;

  const _FilaArticulo({required this.articulo, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final resumen = textoPlano(articulo.contenido);
    final inicio = articulo.esInicioDeGuia;

    return InkWell(
      key: Key('articulo-${articulo.id}'),
      onTap: alTocar,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            if (inicio) ...[
              Icon(Icons.map_outlined, color: AppColors.acentoClaro, size: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    articulo.titulo,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (resumen.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }
}
