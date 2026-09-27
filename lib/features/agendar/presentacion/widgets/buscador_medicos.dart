import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/tema/tokens.dart';

/// El buscador de médicos por nombre.
///
/// Lo escrito vive en el bloc (`AgendarState.busqueda`): este campo solo lo
/// refleja, así «Borrar búsqueda» desde otro lugar también lo vacía. La
/// tecla del teclado es «buscar» y cierra el teclado: la lista ya se filtra
/// mientras se escribe.
class BuscadorMedicos extends StatefulWidget {
  final String texto;
  final ValueChanged<String> alCambiar;

  const BuscadorMedicos({
    super.key,
    required this.texto,
    required this.alCambiar,
  });

  @override
  State<BuscadorMedicos> createState() => _BuscadorMedicosState();
}

class _BuscadorMedicosState extends State<BuscadorMedicos> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.texto,
  );

  @override
  void didUpdateWidget(BuscadorMedicos anterior) {
    super.didUpdateWidget(anterior);

    if (widget.texto != _controlador.text) _controlador.text = widget.texto;
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _borrar() {
    cerrarTeclado();
    widget.alCambiar('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('buscar-medico'),
      controller: _controlador,
      onChanged: widget.alCambiar,
      onSubmitted: (_) => cerrarTeclado(),
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoracionCliniq(
        pista: 'Buscar médico por nombre',
        icono: Icons.search_rounded,
        sufijo: widget.texto.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textoSecundario,
                ),
                onPressed: _borrar,
              ),
      ),
    );
  }
}
