// lib/features/mediciones/presentacion/registrar_medicion_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/fechas/fecha_local.dart';
import '../../../core/fechas/instante.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import '../dominio/reglas_mediciones.dart';
import '../providers/registrar_medicion_cubit.dart';
import 'widgets/partes_mediciones.dart';

/// «Registrar»: el valor de un aparato de casa (tensiómetro, oxímetro,
/// termómetro, glucómetro, balanza) o el pulso o las respiraciones contados
/// a mano, con el momento (en reposo, tras actividad, en ayunas, después de
/// comer) y la hora, que por defecto es ahora. Sin red queda pendiente en
/// el teléfono. Al guardar devuelve `true`.
class RegistrarMedicionPage extends StatelessWidget {
  final String? pacienteId;
  final String? pacienteNombre;

  /// La cita o la consulta desde la que se abrió: se ofrece compartir.
  final DestinoMedico? destino;

  final ColaMediciones? cola;

  const RegistrarMedicionPage({
    super.key,
    this.pacienteId,
    this.pacienteNombre,
    this.destino,
    this.cola,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';

    return BlocProvider(
      create: (_) => RegistrarMedicionCubit(
        cola: cola ?? Servicios.colaMediciones,
        uid: uid,
        pacienteId: pacienteId,
        citaId: destino?.citaId,
        consultaId: destino?.consultaId,
        ahora: Servicios.reloj.instante,
      ),
      child: _Formulario(pacienteNombre: pacienteNombre, destino: destino),
    );
  }
}

class _Formulario extends StatefulWidget {
  final String? pacienteNombre;
  final DestinoMedico? destino;

  const _Formulario({required this.pacienteNombre, required this.destino});

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _valor = TextEditingController();
  final _valor2 = TextEditingController();
  final _notas = TextEditingController();

  @override
  void dispose() {
    _valor.dispose();
    _valor2.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _elegirTipo(TipoMedicion tipo) {
    _valor.clear();
    _valor2.clear();
    context.read<RegistrarMedicionCubit>().elegirTipo(tipo);
  }

  /// Fecha y hora en la hora de la clínica, de los últimos 30 días.
  Future<void> _elegirHora(DateTime? actual) async {
    final cubit = context.read<RegistrarMedicionCubit>();
    final ahora = Servicios.reloj.ahora();
    final inicial = actual == null ? ahora : enHoraDeLaClinica(actual);

    final dia = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: ahora.subtract(antiguedadMaxima),
      lastDate: ahora,
      helpText: 'Día de la medición',
    );
    if (dia == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
      helpText: 'Hora de la medición',
    );
    if (hora == null) return;

    final local = DateTime(
      dia.year,
      dia.month,
      dia.day,
      hora.hour,
      hora.minute,
    );
    cubit.elegirMomento(RelojClinica.fijo(local).instante());
  }

  void _guardar() {
    cerrarTeclado();
    context.read<RegistrarMedicionCubit>().guardar(
      valor: _valor.text,
      valor2: _valor2.text,
      notas: _notas.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegistrarMedicionCubit, RegistrarMedicionState>(
      listenWhen: (antes, ahora) =>
          ahora.registro != null && antes.registro != ahora.registro,
      listener: (context, state) {
        mostrarAviso(
          context,
          state.registro is RegistroPendiente
              ? 'Sin conexión: la guardamos en este teléfono y la enviaremos '
                    'cuando vuelva la conexión.'
              : 'Medición guardada.',
        );
        Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final cubit = context.read<RegistrarMedicionCubit>();
        final tipo = state.tipo;
        final metodos = metodosDelFormulario(tipo);
        final contextos = contextosDelTipo(tipo);
        final decimales = decimalesDelTipo(tipo);
        final formato = [
          FilteringTextInputFormatter.allow(
            RegExp(decimales > 0 ? r'[0-9.,]' : r'[0-9]'),
          ),
          LengthLimitingTextInputFormatter(6),
        ];
        final teclado = TextInputType.numberWithOptions(decimal: decimales > 0);
        final unidad = unidadDelTipo(tipo);
        final medidoEn = state.medidoEn;

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Registrar medición')),
          bottomNavigationBar: BarraDeAccion(
            child: BotonPrincipal(
              key: const Key('registrar-guardar'),
              texto: 'Guardar',
              icono: Icons.save_alt_rounded,
              cargando: state.guardando,
              textoCargando: 'Guardando…',
              onPressed: _guardar,
            ),
          ),
          body: FondoDegradado(
            child: ListView(
              padding: context.margenDeScroll(superior: 16, inferior: 24),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Puedes registrar igual: quedará en este teléfono y se '
                      'enviará cuando vuelva la conexión.',
                ),
                if (widget.pacienteNombre != null) ...[
                  RecuadroAviso.informacion(
                    'Para ${widget.pacienteNombre}.',
                    icono: Icons.family_restroom_rounded,
                  ),
                  const SizedBox(height: 14),
                ],
                const EtiquetaSeccion('¿Qué mediste?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in tiposParaRegistrar)
                      ChipDeOpcion(
                        key: Key('tipo-${t.codigo}'),
                        texto: nombreDelTipo(t),
                        icono: iconoDelTipo(t),
                        elegido: t == tipo,
                        onTap: () => _elegirTipo(t),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                EtiquetaSeccion('${nombreDelTipo(tipo)} ($unidad)'),
                if (tipo == TipoMedicion.pa)
                  Row(
                    children: [
                      Expanded(
                        child: CampoCliniq(
                          key: const Key('registrar-valor'),
                          controller: _valor,
                          pista: 'Alta (sistólica)',
                          teclado: teclado,
                          formatos: formato,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '/',
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      Expanded(
                        child: CampoCliniq(
                          key: const Key('registrar-valor2'),
                          controller: _valor2,
                          pista: 'Baja (diastólica)',
                          teclado: teclado,
                          formatos: formato,
                        ),
                      ),
                    ],
                  )
                else
                  CampoCliniq(
                    key: const Key('registrar-valor'),
                    controller: _valor,
                    pista: 'Valor en $unidad',
                    icono: iconoDelTipo(tipo),
                    teclado: teclado,
                    formatos: formato,
                  ),
                const SizedBox(height: 6),
                Text(
                  metodos.length == 1
                      ? 'Escribe lo que marca tu ${aparatoDelTipo(tipo)}.'
                      : 'Con tu ${aparatoDelTipo(tipo)}, o contando durante un '
                            'minuto con el reloj.',
                  style: const TextStyle(
                    color: AppColors.textoTenue,
                    fontSize: 12,
                  ),
                ),
                if (metodos.length > 1) ...[
                  const SizedBox(height: 18),
                  const EtiquetaSeccion('¿Cómo lo mediste?'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in metodos)
                        ChipDeOpcion(
                          key: Key('metodo-${m.codigo}'),
                          texto: m == MetodoMedicion.manual
                              ? 'Contando a mano'
                              : 'Con un aparato',
                          elegido: state.metodo == m,
                          onTap: () => cubit.elegirMetodo(m),
                        ),
                    ],
                  ),
                ],
                if (contextos.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const EtiquetaSeccion('¿En qué momento? (opcional)'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in contextos)
                        ChipDeOpcion(
                          key: Key('contexto-${c.codigo}'),
                          texto: nombreDelContexto(c),
                          elegido: state.contexto == c,
                          onTap: () => cubit.elegirContexto(c),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                const EtiquetaSeccion('¿Cuándo?'),
                TarjetaTranslucida(
                  key: const Key('registrar-hora'),
                  onTap: () => _elegirHora(medidoEn),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: AppColors.primarioClaro,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          medidoEn == null
                              ? 'Ahora'
                              : FormatoFecha.cortaConHora(
                                  enHoraDeLaClinica(medidoEn),
                                ),
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (medidoEn != null)
                        TextButton(
                          onPressed: () => cubit.elegirMomento(null),
                          child: const Text('Ahora'),
                        )
                      else
                        Text(
                          'Cambiar',
                          style: TextStyle(color: AppColors.acentoClaro),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const EtiquetaSeccion('Notas (opcional)'),
                CampoCliniq(
                  key: const Key('registrar-notas'),
                  controller: _notas,
                  pista: 'Por ejemplo: después de caminar 20 minutos',
                  lineas: 2,
                  maximo: 300,
                  mayusculas: TextCapitalization.sentences,
                ),
                if (widget.destino != null) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    key: const Key('registrar-compartir'),
                    contentPadding: EdgeInsets.zero,
                    value: state.compartir,
                    onChanged: cubit.alternarCompartir,
                    activeThumbColor: AppColors.acento,
                    title: const Text(
                      'Compartir con mi médico',
                      style: TextStyle(color: AppColors.texto),
                    ),
                    subtitle: Text(
                      widget.destino!.titulo,
                      style: const TextStyle(color: AppColors.textoSecundario),
                    ),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 14),
                  RecuadroAviso.error(
                    state.error!,
                    key: const Key('registrar-error'),
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
