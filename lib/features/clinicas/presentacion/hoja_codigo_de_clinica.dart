// lib/features/clinicas/presentacion/hoja_codigo_de_clinica.dart

import 'package:flutter/material.dart';

import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/tema/tokens.dart';
import '../dominio/clinica.dart';
import '../providers/clinica_cubit.dart';
import 'hoja_elegir_clinica.dart';
import 'logo_de_clinica_publica.dart';

/// Abre la hoja «Código de la clínica». Devuelve `true` si la clínica de la
/// aplicación cambió (se eligió otra o se olvidó la guardada).
Future<bool> cambiarDeClinica(BuildContext context, ClinicaCubit clinicas) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => HojaCodigoDeClinica(clinicas: clinicas),
  ).then((cambio) => cambio ?? false);
}

/// Escribir el código que dio la clínica, verla (logotipo y nombre) y
/// usarla. Con una clínica ya guardada, también se puede olvidar: entonces
/// la API busca la clínica por el correo al entrar.
class HojaCodigoDeClinica extends StatefulWidget {
  final ClinicaCubit clinicas;

  const HojaCodigoDeClinica({super.key, required this.clinicas});

  @override
  State<HojaCodigoDeClinica> createState() => _HojaCodigoDeClinicaState();
}

class _HojaCodigoDeClinicaState extends State<HojaCodigoDeClinica> {
  final TextEditingController _codigo = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _buscando = false;
  bool _guardando = false;
  Clinica? _encontrada;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (_buscando || _formKey.currentState?.validate() != true) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _buscando = true;
      _error = null;
      _encontrada = null;
    });

    final resultado = await widget.clinicas.buscar(_codigo.text);
    if (!mounted) return;

    setState(() {
      _buscando = false;
      _encontrada = resultado is CodigoEncontrado ? resultado.clinica : null;
      _error = mensajeDeBusqueda(resultado, _codigo.text);
    });
  }

  Future<void> _usar(Clinica clinica) async {
    setState(() => _guardando = true);
    final antes = widget.clinicas.clinica;
    await widget.clinicas.elegir(clinica);
    if (mounted) Navigator.of(context).pop(!clinica.esLaMismaQue(antes));
  }

  Future<void> _olvidar() async {
    setState(() => _guardando = true);
    await widget.clinicas.olvidar();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final guardada = widget.clinicas.clinica;
    final encontrada = _encontrada;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AsaDeHoja(),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: const Text(
                  'Cambiar de clínica',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                guardada == null
                    ? 'Escribe el código que te dio tu clínica (viene en su '
                          'enlace de registro o te lo dan en recepción).'
                    : 'Ahora estás en ${guardada.nombre}. Escribe el código '
                          'de la otra clínica.',
                style: const TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (_error case final error?) ...[
                RecuadroAviso.error(error, key: const Key('error-codigo')),
                const SizedBox(height: 14),
              ],
              const EtiquetaCampo('Código de la clínica'),
              CampoCliniq(
                key: const Key('campo-codigo-clinica'),
                controller: _codigo,
                pista: 'Por ejemplo: andina',
                icono: Icons.local_hospital_outlined,
                habilitado: !_buscando && !_guardando,
                accion: TextInputAction.search,
                validator: (valor) => errorDeCodigo(valor ?? ''),
                onChanged: (_) {
                  if (_encontrada != null) setState(() => _encontrada = null);
                },
                onSubmitted: (_) => _buscar(),
              ),
              const SizedBox(height: 16),
              if (encontrada == null)
                BotonPrincipal(
                  key: const Key('boton-buscar-clinica'),
                  texto: 'Buscar mi clínica',
                  icono: Icons.search_rounded,
                  cargando: _buscando,
                  textoCargando: 'Buscando…',
                  onPressed: _guardando ? null : _buscar,
                )
              else ...[
                _ClinicaEncontrada(clinica: encontrada),
                const SizedBox(height: 14),
                BotonPrincipal(
                  key: const Key('boton-usar-clinica'),
                  texto: 'Usar ${encontrada.nombre}',
                  icono: Icons.check_rounded,
                  cargando: _guardando,
                  textoCargando: 'Guardando…',
                  onPressed: () => _usar(encontrada),
                ),
              ],
              if (guardada != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('boton-olvidar-clinica'),
                  onPressed: _guardando || _buscando ? null : _olvidar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textoSecundario,
                  ),
                  child: const Text(
                    'No sé el código: buscar mi clínica con mi correo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La clínica del código: su logotipo y su nombre, para confirmar que es
/// la buena antes de usarla.
class _ClinicaEncontrada extends StatelessWidget {
  final Clinica clinica;

  const _ClinicaEncontrada({required this.clinica});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Encontramos ${clinica.nombre}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppEspaciado.m),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: AppRadio.deTarjeta,
          border: Border.all(color: AppColors.exito.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            LogoDeClinicaPublica(clinica: clinica, tamano: 52),
            const SizedBox(width: AppEspaciado.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Encontramos tu clínica',
                    style: TextStyle(
                      color: AppColors.exito,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    clinica.nombre,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
