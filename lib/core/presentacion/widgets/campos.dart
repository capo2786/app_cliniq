import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tema/tokens.dart';

/// El rótulo sobre un campo de formulario.
class EtiquetaCampo extends StatelessWidget {
  final String texto;

  const EtiquetaCampo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppEspaciado.s),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textoSuave,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

OutlineInputBorder _borde(Color color, [double ancho = 1.2]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: ancho),
  );
}

/// La decoración de todos los campos de Cliniq.
///
/// El icono va en su propia pastilla —separa el símbolo del texto y el campo
/// se lee como un bloque— y el foco enciende un anillo terracota, el mismo
/// color de la acción: dice dónde se está escribiendo sin tener que buscarlo.
InputDecoration decoracionCliniq({
  required String pista,
  IconData? icono,
  Widget? sufijo,
  String? contador,
}) {
  return InputDecoration(
    hintText: pista,
    hintStyle: const TextStyle(
      color: AppColors.textoPista,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: icono == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primarioClaro.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icono, color: AppColors.primarioClaro, size: 18),
            ),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 56),
    suffixIcon: sufijo,
    counterText: contador,
    counterStyle: const TextStyle(color: AppColors.textoTenue, fontSize: 11),
    filled: true,
    fillColor: AppColors.campo,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    errorMaxLines: 3,
    errorStyle: const TextStyle(
      color: AppColors.errorTexto,
      fontWeight: FontWeight.w600,
    ),
    border: _borde(Colors.white.withValues(alpha: 0.08)),
    enabledBorder: _borde(Colors.white.withValues(alpha: 0.08)),
    focusedBorder: _borde(AppColors.acentoClaro, 1.8),
    errorBorder: _borde(AppColors.peligroSuave),
    focusedErrorBorder: _borde(AppColors.peligroSuave, 1.6),
    disabledBorder: _borde(AppColors.bordeDeshabilitado),
  );
}

/// Un campo de texto con el estilo de la aplicación.
class CampoCliniq extends StatelessWidget {
  final TextEditingController controller;
  final String pista;
  final IconData? icono;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool oculto;
  final bool habilitado;
  final TextInputType? teclado;
  final TextInputAction? accion;
  final Iterable<String>? autofill;
  final Widget? sufijo;
  final int lineas;
  final int? maximo;
  final List<TextInputFormatter>? formatos;
  final TextCapitalization mayusculas;
  final FocusNode? foco;
  final bool soloLectura;
  final VoidCallback? onTap;

  const CampoCliniq({
    super.key,
    required this.controller,
    required this.pista,
    this.icono,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.oculto = false,
    this.habilitado = true,
    this.teclado,
    this.accion,
    this.autofill,
    this.sufijo,
    this.lineas = 1,
    this.maximo,
    this.formatos,
    this.mayusculas = TextCapitalization.none,
    this.foco,
    this.soloLectura = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: foco,
      obscureText: oculto,
      enabled: habilitado,
      readOnly: soloLectura,
      onTap: onTap,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      keyboardType: teclado,
      textInputAction: accion,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: !oculto,
      textCapitalization: mayusculas,
      minLines: lineas > 1 ? lineas : null,
      maxLines: oculto ? 1 : (lineas > 1 ? lineas + 3 : 1),
      maxLength: maximo,
      inputFormatters: formatos,
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoracionCliniq(pista: pista, icono: icono, sufijo: sufijo),
    );
  }
}

/// Un selector de una lista, con el mismo aspecto que los campos de texto.
class SelectorCliniq<T> extends StatelessWidget {
  final T? valor;
  final List<T> opciones;
  final String Function(T) etiqueta;
  final ValueChanged<T?>? onChanged;
  final String pista;
  final IconData? icono;
  final String? Function(T?)? validator;

  const SelectorCliniq({
    super.key,
    required this.valor,
    required this.opciones,
    required this.etiqueta,
    required this.onChanged,
    required this.pista,
    this.icono,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: opciones.contains(valor) ? valor : null,
      isExpanded: true,
      items: [
        for (final opcion in opciones)
          DropdownMenuItem<T>(
            value: opcion,
            child: Text(etiqueta(opcion), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: validator,
      dropdownColor: AppColors.tarjeta,
      iconEnabledColor: AppColors.primarioClaro,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoracionCliniq(pista: pista, icono: icono),
    );
  }
}
