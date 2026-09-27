import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../legal/data/legal_service.dart';
import '../../../navegacion/presentacion/enrutador.dart';
import '../../dominio/registro.dart';
import '../../providers/registro_bloc.dart';

/// Los documentos legales del registro, con su casilla cada uno.
///
/// Son los que el API da por aceptados al crear la cuenta (los términos y la
/// privacidad), con el título y la versión de la clínica. «Leer» abre el
/// documento con el lector de la aplicación (`/legal/:slug`, por el
/// enrutador). Debajo, para leerlos, los demás documentos de los pacientes:
/// esos se aceptan al entrar por primera vez.
class DocumentosDelRegistro extends StatelessWidget {
  /// Ya se intentó enviar: si falta una casilla, se dice.
  final bool intentado;

  const DocumentosDelRegistro({super.key, required this.intentado});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegistroBloc>().state;
    final bloc = context.read<RegistroBloc>();
    final habilitado = !state.enviando;

    if (state.cargandoDocumentos) {
      return const CargandoCentro(mensaje: 'Buscando los documentos legales…');
    }

    final errorDocumentos = state.errorDocumentos;
    if (errorDocumentos != null) {
      return EstadoError(
        mensaje: errorDocumentos,
        alReintentar: () => bloc.add(const RegistroDocumentosPedidos()),
      );
    }

    void marcar(String clave, bool? valor) =>
        bloc.add(RegistroDocumentoMarcado(clave, aceptado: valor ?? false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.documentos.isEmpty)
          _CasillaSinDocumentos(
            aceptado: state.aceptados.contains(casillaSinDocumentos),
            alCambiar: habilitado
                ? (valor) => marcar(casillaSinDocumentos, valor)
                : null,
          )
        else
          for (final documento in state.documentos) ...[
            _DocumentoPorAceptar(
              documento: documento,
              aceptado: state.aceptados.contains(documento.clave),
              alCambiar: habilitado
                  ? (valor) => marcar(documento.clave, valor)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
        const Text(
          'Al aceptarlos autorizas el tratamiento de tus datos de salud para '
          'tu atención.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (intentado && !state.todoAceptado) ...[
          const SizedBox(height: 8),
          const Text(
            mensajeFaltaAceptar,
            key: Key('error-documentos-registro'),
            style: TextStyle(
              color: AppColors.errorTexto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (state.documentosAlEntrar.isNotEmpty) ...[
          const SizedBox(height: 16),
          _DocumentosAlEntrar(documentos: state.documentosAlEntrar),
        ],
      ],
    );
  }
}

/// Abre un documento con el lector de la aplicación, por el enrutador.
void _leer(BuildContext context, DocumentoLegal documento) => abrirRuta(
  context,
  '/legal/${Uri.encodeComponent(documento.slug)}',
  titulo: documento.titulo,
);

class _DocumentoPorAceptar extends StatelessWidget {
  final DocumentoLegal documento;
  final bool aceptado;
  final ValueChanged<bool?>? alCambiar;

  const _DocumentoPorAceptar({
    required this.documento,
    required this.aceptado,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      tinte: aceptado ? AppColors.exito : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.primarioClaro,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _TituloDocumento(documento: documento)),
              TextButton.icon(
                key: Key('leer-registro-${documento.clave}'),
                onPressed: () => _leer(context, documento),
                icon: const Icon(Icons.menu_book_outlined, size: 17),
                label: const Text('Leer'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.acentoSuave,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            key: Key('aceptar-registro-${documento.clave}'),
            value: aceptado,
            onChanged: alCambiar,
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

class _TituloDocumento extends StatelessWidget {
  final DocumentoLegal documento;

  const _TituloDocumento({required this.documento});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          documento.titulo,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (documento.version.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Versión ${documento.version}',
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// La clínica no tiene vigente ninguno de los documentos del registro: la
/// aceptación igual hace falta, en una sola casilla y sin enlaces.
class _CasillaSinDocumentos extends StatelessWidget {
  final bool aceptado;
  final ValueChanged<bool?>? alCambiar;

  const _CasillaSinDocumentos({
    required this.aceptado,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      tinte: aceptado ? AppColors.exito : null,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: CheckboxListTile(
        key: const Key('aceptar-registro-general'),
        value: aceptado,
        onChanged: alCambiar,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: const Text(
          'He leído y acepto los términos y condiciones y la política de '
          'privacidad',
          style: TextStyle(
            color: AppColors.textoSuave,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Los documentos de los pacientes que se aceptan al entrar por primera vez:
/// se pueden leer desde ya.
class _DocumentosAlEntrar extends StatelessWidget {
  final List<DocumentoLegal> documentos;

  const _DocumentosAlEntrar({required this.documentos});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Al entrar por primera vez te pediremos aceptar también:',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          for (final documento in documentos)
            Row(
              children: [
                Expanded(
                  child: Text(
                    documento.titulo,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  key: Key('leer-registro-${documento.clave}'),
                  onPressed: () => _leer(context, documento),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.acentoSuave,
                  ),
                  child: const Text('Leer'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
