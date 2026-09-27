// lib/features/ayuda/presentacion/widgets/buscador_de_ayuda.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/tema/tokens.dart';

/// La cabecera del centro de ayuda con su buscador.
///
/// Busca mientras se escribe, tras una [pausa] sin teclear (para no pedir
/// por cada letra), y al tocar «buscar» en el teclado, enseguida y cerrando
/// el teclado.
class BuscadorDeAyuda extends StatefulWidget {
  final void Function(String texto) alBuscar;
  final Duration pausa;

  const BuscadorDeAyuda({
    super.key,
    required this.alBuscar,
    this.pausa = const Duration(milliseconds: 300),
  });

  @override
  State<BuscadorDeAyuda> createState() => _BuscadorDeAyudaState();
}

class _BuscadorDeAyudaState extends State<BuscadorDeAyuda> {
  final TextEditingController _texto = TextEditingController();
  Timer? _espera;

  /// Lo último que se mandó a buscar: no se repite la misma búsqueda.
  String _buscado = '';

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _buscar(String texto) {
    _espera?.cancel();

    final limpio = texto.trim();
    if (limpio == _buscado) return;

    _buscado = limpio;
    widget.alBuscar(limpio);
  }

  void _alEscribir(String texto) {
    setState(() {}); // la cruz para borrar aparece o se va
    _espera?.cancel();
    _espera = Timer(widget.pausa, () => _buscar(texto));
  }

  void _alEnviar(String texto) {
    cerrarTeclado();
    _buscar(texto);
  }

  void _borrar() {
    _texto.clear();
    setState(() {});
    _buscar('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: AppGradientes.encabezado,
        borderRadius: AppRadio.dePanel,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿En qué te ayudamos?',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Guías cortas para agendar, usar tu cuenta y resolver lo más '
            'común.',
            style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('campo-buscar-ayuda'),
            controller: _texto,
            textInputAction: TextInputAction.search,
            onChanged: _alEscribir,
            onSubmitted: _alEnviar,
            cursorColor: AppColors.acentoClaro,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: decoracionCliniq(
              pista: 'Por ejemplo: cancelar una cita',
              icono: Icons.search_rounded,
              sufijo: _texto.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar la búsqueda',
                      onPressed: _borrar,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textoSecundario,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
