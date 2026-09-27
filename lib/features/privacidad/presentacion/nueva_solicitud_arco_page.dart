// lib/features/privacidad/presentacion/nueva_solicitud_arco_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/estilo_de_catalogo.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/tema/tokens.dart';
import '../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../dominio/reglas_arco.dart';
import '../providers/arco_cubit.dart';

/// Una solicitud ARCO nueva: qué derecho se ejerce y qué se necesita.
///
/// Los derechos que se ofrecen, su orden, su nombre y su explicación salen
/// del catálogo `TIPO_ARCO` (solo los activos). El detalle tiene los mismos
/// límites que el panel y el API. Necesita el [ArcoCubit] de la lista, para
/// que la solicitud nueva aparezca ahí al volver.
class NuevaSolicitudArcoPage extends StatefulWidget {
  const NuevaSolicitudArcoPage({super.key});

  @override
  State<NuevaSolicitudArcoPage> createState() => _NuevaSolicitudArcoPageState();
}

class _NuevaSolicitudArcoPageState extends State<NuevaSolicitudArcoPage> {
  final _formulario = GlobalKey<FormState>();
  final _detalle = TextEditingController();
  String? _tipo;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  /// El elegido, o el primero que se ofrece (Acceso, si la clínica lo
  /// ofrece: es el más común, como en el panel).
  String _tipoElegido(List<String> ofrecidos) {
    final elegido = _tipo;
    if (elegido != null && ofrecidos.contains(elegido)) return elegido;

    return ofrecidos.contains('ACCESO') ? 'ACCESO' : ofrecidos.first;
  }

  Future<void> _enviar(String tipo) async {
    cerrarTeclado();
    if (!(_formulario.currentState?.validate() ?? false)) return;

    final enviada = await context.read<ArcoCubit>().enviar(
      tipo: tipo,
      detalle: _detalle.text,
    );

    if (!enviada || !mounted) return;

    mostrarAviso(
      context,
      'Solicitud enviada. Te avisaremos cuando tengamos una respuesta.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    final ofrecidos = catalogos.codigosOfrecidos(Catalogos.tipoArco, tiposArco);
    final tipo = _tipoElegido(ofrecidos);

    return BlocBuilder<ArcoCubit, ArcoState>(
      builder: (context, state) {
        final error = state.errorAlEnviar;

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Nueva solicitud')),
          bottomNavigationBar: BarraDeAccion(
            child: ConRed(
              builder: (context, hayRed) => BotonPrincipal(
                key: const Key('enviar-solicitud-arco'),
                texto: 'Enviar solicitud',
                icono: Icons.send_rounded,
                cargando: state.enviando,
                textoCargando: 'Enviando…',
                onPressed: hayRed ? () => _enviar(tipo) : null,
              ),
            ),
          ),
          body: FondoDegradado(
            child: Form(
              key: _formulario,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: context.margenDeScroll(),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer:
                        'Para enviar la solicitud necesitas conexión.',
                  ),
                  const EtiquetaSeccion('¿Qué quieres pedir?'),
                  for (final codigo in ofrecidos) ...[
                    _OpcionDerecho(
                      estilo: EstiloDeCatalogo.de(
                        catalogos,
                        Catalogos.tipoArco,
                        codigo,
                      ),
                      codigo: codigo,
                      elegida: codigo == tipo,
                      alElegir: () => setState(() => _tipo = codigo),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  const EtiquetaCampo('Cuéntanos qué necesitas'),
                  CampoCliniq(
                    key: const Key('campo-detalle-arco'),
                    controller: _detalle,
                    pista:
                        ayudaTipoArco[tipo] ??
                        'Describe lo que necesitas de tus datos.',
                    lineas: 5,
                    maximo: detalleArcoMaximo,
                    teclado: TextInputType.multiline,
                    accion: TextInputAction.newline,
                    mayusculas: TextCapitalization.sentences,
                    validator: validarDetalleArco,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Para proteger tus datos, podemos pedirte que confirmes tu '
                    'identidad.',
                    style: TextStyle(
                      color: AppColors.textoTenue,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    RecuadroAviso.error(error),
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

/// Un derecho para elegir, con su explicación del catálogo.
class _OpcionDerecho extends StatelessWidget {
  final EstiloDeCatalogo estilo;
  final String codigo;
  final bool elegida;
  final VoidCallback alElegir;

  const _OpcionDerecho({
    required this.estilo,
    required this.codigo,
    required this.elegida,
    required this.alElegir,
  });

  @override
  Widget build(BuildContext context) {
    return OpcionSeleccionable(
      key: Key('derecho-$codigo'),
      titulo: estilo.nombre,
      descripcion: estilo.descripcion.isEmpty ? null : estilo.descripcion,
      icono: estilo.icono,
      color: estilo.color,
      elegida: elegida,
      onTap: alElegir,
    );
  }
}
