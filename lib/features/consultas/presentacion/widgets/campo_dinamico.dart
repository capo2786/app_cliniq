import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/campo_formulario.dart';
import '../../dominio/reglas_consultas.dart';

/// Una pregunta del formulario de un motivo, con el control que le toca a su
/// tipo: texto corto o largo, número con su unidad, una opción de una lista,
/// sí o no, o una fecha.
///
/// El valor vive en el bloc; aquí solo se pinta y se avisa de cada cambio.
/// Los campos de texto guardan su propio controlador para no perder el
/// cursor con cada letra.
class CampoDinamico extends StatefulWidget {
  final CampoFormulario campo;
  final Object? valor;

  /// El error a la vista, o `null` si no hay (o todavía no se enseñan).
  final String? error;

  final ValueChanged<Object?> alCambiar;
  final bool habilitado;

  const CampoDinamico({
    super.key,
    required this.campo,
    required this.valor,
    required this.alCambiar,
    this.error,
    this.habilitado = true,
  });

  @override
  State<CampoDinamico> createState() => _CampoDinamicoState();
}

class _CampoDinamicoState extends State<CampoDinamico> {
  late final TextEditingController _texto = TextEditingController(
    text: _textoInicial(),
  );

  String _textoInicial() {
    final valor = widget.valor;
    if (valor == null) return '';
    if (valor is num) return numeroLegible(valor);
    return valor.toString();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  CampoFormulario get _campo => widget.campo;

  @override
  Widget build(BuildContext context) {
    final ayuda = _campo.ayuda;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaCampo(
          _campo.requerido ? '${_campo.etiqueta} *' : _campo.etiqueta,
        ),
        if (ayuda != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              ayuda,
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        _control(context),
        if (widget.error != null && !_muestraErrorPropio)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              widget.error!,
              style: const TextStyle(
                color: AppColors.errorTexto,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Los campos de texto pintan el error dentro de su propio borde.
  bool get _muestraErrorPropio => switch (_campo.tipo) {
    TipoCampo.texto || TipoCampo.textoLargo || TipoCampo.numero => true,
    _ => false,
  };

  Widget _control(BuildContext context) {
    return switch (_campo.tipo) {
      TipoCampo.texto => _campoDeTexto(lineas: 1),
      TipoCampo.textoLargo => _campoDeTexto(lineas: 4),
      TipoCampo.numero => _campoNumerico(),
      TipoCampo.seleccion => _seleccion(),
      TipoCampo.siNo => _siNo(),
      TipoCampo.fecha => _fecha(context),
    };
  }

  Widget _campoDeTexto({required int lineas}) {
    return TextField(
      key: Key('campo-${_campo.clave}'),
      controller: _texto,
      enabled: widget.habilitado,
      minLines: lineas,
      maxLines: lineas == 1 ? 1 : lineas + 4,
      maxLength: lineas == 1 ? 300 : maximoDescripcion,
      textCapitalization: TextCapitalization.sentences,
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(color: AppColors.texto, fontSize: 15, height: 1.4),
      decoration: decoracionCliniq(
        pista: lineas == 1 ? 'Tu respuesta' : 'Cuéntalo con tus palabras',
        contador: '',
      ).copyWith(errorText: widget.error),
      onChanged: widget.alCambiar,
    );
  }

  Widget _campoNumerico() {
    final unidad = _campo.unidad;

    return TextField(
      key: Key('campo-${_campo.clave}'),
      controller: _texto,
      enabled: widget.habilitado,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
        LengthLimitingTextInputFormatter(12),
      ],
      cursorColor: AppColors.acentoClaro,
      style: const TextStyle(
        color: AppColors.texto,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration:
          decoracionCliniq(
            pista: 'Ej.: 37,5',
            icono: Icons.pin_outlined,
          ).copyWith(
            errorText: widget.error,
            suffixText: unidad,
            suffixStyle: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
      onChanged: widget.alCambiar,
    );
  }

  Widget _seleccion() {
    final opciones = _campo.opciones;

    // Pocas opciones se eligen de un toque; muchas, en una lista.
    if (opciones.length <= 5) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final opcion in opciones)
            _Ficha(
              texto: opcion,
              elegida: widget.valor == opcion,
              onTap: widget.habilitado
                  ? () => widget.alCambiar(
                      widget.valor == opcion && !_campo.requerido
                          ? null
                          : opcion,
                    )
                  : null,
            ),
        ],
      );
    }

    return SelectorCliniq<String>(
      key: Key('campo-${_campo.clave}'),
      valor: widget.valor is String ? widget.valor as String : null,
      opciones: opciones,
      etiqueta: (o) => o,
      pista: 'Elige una opción',
      icono: Icons.list_rounded,
      onChanged: widget.habilitado ? widget.alCambiar : null,
    );
  }

  Widget _siNo() {
    return Row(
      children: [
        for (final (valor, texto) in const [(true, 'Sí'), (false, 'No')]) ...[
          Expanded(
            child: _Ficha(
              texto: texto,
              elegida: widget.valor == valor,
              ancha: true,
              onTap: widget.habilitado
                  ? () => widget.alCambiar(
                      widget.valor == valor && !_campo.requerido ? null : valor,
                    )
                  : null,
            ),
          ),
          if (valor) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _fecha(BuildContext context) {
    final fecha = deFechaIso(widget.valor?.toString());

    Future<void> elegir() async {
      final hoy = Servicios.reloj.hoy();
      final elegida = await showDatePicker(
        context: context,
        initialDate: fecha ?? hoy,
        firstDate: DateTime(1900),
        lastDate: sumarDias(hoy, 365),
        helpText: _campo.etiqueta,
        cancelText: 'Cancelar',
        confirmText: 'Elegir',
      );

      if (elegida != null) widget.alCambiar(fechaIso(elegida));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('campo-${_campo.clave}'),
        onTap: widget.habilitado ? elegir : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.campo,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.error != null
                  ? AppColors.peligroSuave
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_rounded,
                color: AppColors.primarioClaro,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fecha == null
                      ? 'Elige una fecha'
                      : FormatoFecha.diaLargoConAnio(fecha),
                  style: TextStyle(
                    color: fecha == null
                        ? AppColors.textoPista
                        : AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (fecha != null && !_campo.requerido && widget.habilitado)
                GestureDetector(
                  onTap: () => widget.alCambiar(null),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textoSecundario,
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una ficha que se elige tocándola.
class _Ficha extends StatelessWidget {
  final String texto;
  final bool elegida;
  final bool ancha;
  final VoidCallback? onTap;

  const _Ficha({
    required this.texto,
    required this.elegida,
    this.ancha = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: elegida
                  ? AppColors.acento.withValues(alpha: 0.16)
                  : AppColors.campo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: elegida ? AppColors.acentoClaro : AppColors.bordeCampo,
                width: elegida ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: ancha ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (elegida) ...[
                  Icon(
                    Icons.check_rounded,
                    color: AppColors.acentoClaro,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: elegida ? AppColors.texto : AppColors.textoSuave,
                      fontSize: 13.5,
                      fontWeight: elegida ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
