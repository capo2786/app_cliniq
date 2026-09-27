// lib/features/legal/presentacion/aceptacion_legal_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/enlaces.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_event.dart';
import '../data/legal_service.dart';
import '../providers/legal_bloc.dart';
import '../../../core/configuracion/en_contexto.dart';

/// Los documentos legales pendientes, antes de todo lo demás.
///
/// Bloquea a propósito: la clínica necesita la aceptación de la versión
/// vigente para atender, y una aplicación que dejara pasar sin ella
/// terminaría con citas de personas que no aceptaron el consentimiento de
/// telemedicina. La única otra salida es cerrar sesión.
class AceptacionLegalPage extends StatelessWidget {
  final LegalService? servicio;

  const AceptacionLegalPage({super.key, this.servicio});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LegalBloc(servicio ?? Servicios.legal)..add(const LegalSolicitado()),
      child: const _VistaLegal(),
    );
  }
}

class _VistaLegal extends StatelessWidget {
  const _VistaLegal();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LegalBloc, LegalState>(
      listenWhen: (antes, ahora) => !antes.completo && ahora.completo,
      listener: (context, state) {
        final auth = context.read<AuthBloc>();
        final usuario = auth.usuario;

        // Se deja pasar en el acto, sin esperar a releer el perfil: la
        // aceptación ya quedó registrada. Después se relee igual.
        if (usuario != null) {
          auth.add(
            AuthPerfilActualizado(
              Usuario({...usuario.datos, 'legalPendientes': <String>[]}),
            ),
          );
        }
        auth.add(const AuthPerfilRefrescado());
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Antes de continuar'),
            actions: const [BotonCerrarSesion(), SizedBox(width: 6)],
          ),
          body: FondoDegradado(
            child: ListView(
              padding: context.margenDeScroll(),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Para aceptar los documentos necesitas '
                      'conexión.',
                ),
                EntradaAnimada(
                  child: TarjetaEncabezado(
                    icono: Icons.gavel_rounded,
                    titulo: 'Documentos por aceptar',
                    descripcion:
                        'Para atenderte en ${context.config.clinica.nombre} '
                        'necesitamos que leas y aceptes estos documentos. '
                        'Cada uno se abre en tu navegador.',
                  ),
                ),
                const SizedBox(height: 22),
                if (state.cargando)
                  const CargandoCentro(mensaje: 'Buscando documentos…')
                else if (state.error != null && state.pendientes.isEmpty)
                  EstadoError(
                    mensaje: state.error!,
                    alReintentar: () =>
                        context.read<LegalBloc>().add(const LegalSolicitado()),
                  )
                else ...[
                  const EtiquetaSeccion('Pendientes'),
                  for (final documento in state.pendientes) ...[
                    _TarjetaDocumento(
                      documento: documento,
                      aceptado: state.marcados.contains(documento.clave),
                      habilitado: !state.enviando,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.error != null) ...[
                    RecuadroAviso.error(state.error!),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 10),
                  ConRed(
                    builder: (context, hayRed) => BotonPrincipal(
                      texto: 'Aceptar y continuar',
                      icono: Icons.check_circle_outline_rounded,
                      cargando: state.enviando,
                      textoCargando: 'Registrando…',
                      onPressed: state.todosMarcados && hayRed
                          ? () => context.read<LegalBloc>().add(
                              const LegalAceptado(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.todosMarcados
                        ? 'Guardaremos la fecha y la versión de cada '
                              'documento que aceptas.'
                        : 'Marca cada documento para continuar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoTenue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaDocumento extends StatelessWidget {
  final DocumentoPendiente documento;
  final bool aceptado;
  final bool habilitado;

  const _TarjetaDocumento({
    required this.documento,
    required this.aceptado,
    required this.habilitado,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      tinte: aceptado ? AppColors.exito : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.primarioClaro,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documento.titulo,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Versión ${documento.version}',
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (documento.url case final url?)
                TextButton.icon(
                  onPressed: () => abrirEnlace(context, url),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Leer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.acentoSuave,
                  ),
                ),
            ],
          ),
          CheckboxListTile(
            value: aceptado,
            onChanged: habilitado
                ? (valor) => context.read<LegalBloc>().add(
                    LegalMarcado(documento.clave, aceptado: valor ?? false),
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text(
              'He leído y acepto este documento',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
