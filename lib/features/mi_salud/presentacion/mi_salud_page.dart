// lib/features/mi_salud/presentacion/mi_salud_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/estilo_de_catalogo.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../consultas/presentacion/widgets/adjuntos.dart';
import '../../dependientes/data/dependientes_service.dart';
import '../../mediciones/presentacion/widgets/accesos_signos_vitales.dart';
import '../data/mi_salud_service.dart';
import '../data/models/mi_salud.dart';
import '../dominio/reglas_mi_salud.dart';
import '../providers/mi_salud_cubit.dart';
import 'certificado_page.dart';
import 'orden_page.dart';
import 'receta_page.dart';
import 'visor_pdf_page.dart';
import 'widgets/partes_documento.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// «Mi salud»: lo que el paciente tiene derecho a ver de su historia
/// clínica, como en el panel. Su ficha y sus alergias, las últimas
/// mediciones y, por consulta, los diagnósticos, las indicaciones, las
/// recetas, las órdenes, los certificados de reposo y los adjuntos clínicos.
/// También los de sus dependientes, si la cuenta los gestiona. Una receta,
/// una orden o un certificado firmado lo dice, y cada uno vigente ofrece
/// «Ver PDF» (el firmado o la vista previa; si el servidor no lo da, su
/// mensaje).
///
/// Sin conexión enseña la última copia guardada; sin copia, lo dice con
/// «Reintentar».
class MiSaludPage extends StatelessWidget {
  /// Por defecto, `Servicios.miSalud`.
  final MiSaludService? servicio;

  /// Por defecto, `Servicios.dependientes`.
  final DependientesService? dependientes;

  const MiSaludPage({super.key, this.servicio, this.dependientes});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthBloc>().usuario;
    final conDependientes = usuario?.puede(Permisos.dependientes) ?? false;

    return BlocProvider(
      create: (_) => MiSaludCubit(
        servicio: servicio ?? Servicios.miSalud,
        uid: usuario?.uid ?? '',
        dependientes: conDependientes
            ? (dependientes ?? Servicios.dependientes)
            : null,
      )..iniciar(),
      child: const _VistaMiSalud(),
    );
  }
}

class _VistaMiSalud extends StatefulWidget {
  const _VistaMiSalud();

  @override
  State<_VistaMiSalud> createState() => _VistaMiSaludState();
}

class _VistaMiSaludState extends State<_VistaMiSalud> {
  /// La atención abierta. Mientras la persona no toque ninguna, la más
  /// reciente (como en el panel).
  String? _abierta;
  bool _eligio = false;

  void _alternar(String id, String? actual) => setState(() {
    _eligio = true;
    _abierta = actual == id ? null : id;
  });

  void _elegirPersona(String para) {
    setState(() {
      _eligio = false;
      _abierta = null;
    });
    context.read<MiSaludCubit>().elegir(para);
  }

  @override
  Widget build(BuildContext context) {
    final nombreClinica = context.config.clinica.nombre;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Mi salud'),
        actions: const [
          BotonAyuda(clave: 'app.miSalud'),
          BotonCerrarSesion(),
          SizedBox(width: 6),
        ],
      ),
      body: FondoDegradado(
        child: BlocBuilder<MiSaludCubit, MiSaludState>(
          builder: (context, state) {
            final cubit = context.read<MiSaludCubit>();
            final datos = state.datos;
            final atenciones = datos?.atenciones ?? const <AtencionMiSalud>[];
            final abierta = _eligio ? _abierta : atenciones.firstOrNull?.id;

            return RefreshIndicator(
              color: AppColors.acentoClaro,
              backgroundColor: AppColors.superficie,
              onRefresh: cubit.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.margenDeScroll(inferior: 28),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer:
                        'Mostramos lo último que guardamos de tu historia '
                        'clínica en este teléfono.',
                  ),
                  TarjetaEncabezado(
                    icono: Icons.favorite_border_rounded,
                    titulo: 'Mi salud',
                    descripcion:
                        'Tus diagnósticos, indicaciones, recetas, órdenes y '
                        'certificados de cada consulta en $nombreClinica.',
                  ),
                  if (state.dependientes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChipDeOpcion(
                          key: const Key('para-yo'),
                          texto: 'Yo',
                          icono: Icons.person_outline_rounded,
                          elegido: state.para.isEmpty,
                          onTap: () => _elegirPersona(''),
                        ),
                        for (final d in state.dependientes)
                          ChipDeOpcion(
                            key: Key('para-${d.uid}'),
                            texto: d.nombre,
                            icono: Icons.family_restroom_rounded,
                            elegido: state.para == d.uid,
                            onTap: () => _elegirPersona(d.uid),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (datos == null)
                    state.carga == CargaMiSalud.error
                        ? EstadoError(
                            mensaje:
                                state.error ??
                                'No pudimos cargar tu historia clínica.',
                            alReintentar: cubit.cargar,
                          )
                        : const CargandoCentro(
                            mensaje: 'Cargando tu historia clínica…',
                          )
                  else ...[
                    if (state.desdeCache && state.guardadaEn != null) ...[
                      RecuadroAviso.informacion(
                        'Mostramos la copia guardada el '
                        '${FormatoFecha.cortaConHora(state.guardadaEn!)}.',
                        icono: Icons.offline_pin_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.error != null) ...[
                      RecuadroAviso.alerta(state.error!),
                      const SizedBox(height: 12),
                    ],
                    const EtiquetaSeccion('Ficha'),
                    _Ficha(paciente: datos.paciente),
                    if (_hayMediciones(datos.ultimosSignos)) ...[
                      const SizedBox(height: 22),
                      _Mediciones(signos: datos.ultimosSignos!),
                    ],
                    AccesoSignosVitales(
                      pacienteId: state.para.isEmpty ? null : state.para,
                      nombre: state.para.isEmpty ? null : datos.paciente.nombre,
                    ),
                    const SizedBox(height: 22),
                    const EtiquetaSeccion('Consultas'),
                    if (atenciones.isEmpty)
                      const EstadoVacio(
                        icono: Icons.favorite_border_rounded,
                        titulo: 'Aún no hay consultas registradas',
                        descripcion:
                            'Después de cada consulta verás aquí tus '
                            'diagnósticos, indicaciones, recetas, órdenes y '
                            'certificados.',
                      )
                    else
                      for (final atencion in atenciones) ...[
                        _TarjetaAtencion(
                          atencion: atencion,
                          abierta: atencion.id == abierta,
                          alTocar: () => _alternar(atencion.id, abierta),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

bool _hayMediciones(SignosVitales? s) =>
    s != null &&
    (s.presionSistolica != null ||
        s.presionDiastolica != null ||
        s.pesoKg != null ||
        s.imc != null ||
        s.glucemiaMgDl != null);

/// Quién es, sus alergias (en rojo si tiene), el embarazo en curso, los
/// antecedentes y la medicación habitual.
class _Ficha extends StatelessWidget {
  final FichaClinica paciente;

  const _Ficha({required this.paciente});

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    final edad = paciente.edad;
    final sexo = paciente.sexo == null
        ? null
        : catalogos.nombreDe(Catalogos.sexo, paciente.sexo) ?? paciente.sexo;
    final sangre = paciente.tipoSangre == null
        ? null
        : catalogos.nombreDe(Catalogos.tipoSangre, paciente.tipoSangre) ??
              paciente.tipoSangre;

    final gestacion = paciente.embarazoActual
        ? datosGestacionales(
            paciente.fum,
            context.config.clinico.diasGestacion,
            Servicios.reloj.hoy(),
          )
        : null;

    final alergias = paciente.alergias;

    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paciente.nombre,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (edad != null || sexo != null || sangre != null) ...[
            const SizedBox(height: 3),
            Text(
              [
                if (edad != null) '$edad años',
                ?sexo,
                if (sangre != null) 'Sangre $sangre',
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            key: const Key('ficha-alergias'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (alergias == null ? AppColors.bordeCampo : AppColors.peligro)
                      .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RotuloPequeno('Alergias'),
                const SizedBox(height: 3),
                Text(
                  alergias ?? 'No registradas',
                  style: TextStyle(
                    color: alergias == null
                        ? AppColors.textoSecundario
                        : AppColors.errorTextoClaro,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (gestacion != null) ...[
            const SizedBox(height: 10),
            RecuadroAviso(
              mensaje:
                  'Embarazo: ${gestacion.semanas} semanas '
                  '${gestacion.dias} días · fecha probable de parto el '
                  '${FormatoFecha.diaLargoConAnio(gestacion.fpp).toLowerCase()}.',
              icono: Icons.pregnant_woman_rounded,
              color: AppColors.acentoClaro,
              colorTexto: AppColors.texto,
            ),
          ],
          if (paciente.antecedentesPersonales != null) ...[
            const SizedBox(height: 14),
            BloqueDeTexto(
              rotulo: 'Antecedentes',
              texto: paciente.antecedentesPersonales!,
            ),
          ],
          if (paciente.medicacionHabitual != null)
            BloqueDeTexto(
              rotulo: 'Medicación habitual',
              texto: paciente.medicacionHabitual!,
            ),
        ],
      ),
    );
  }
}

/// Las últimas mediciones: presión, peso, IMC y glucemia (las del panel).
class _Mediciones extends StatelessWidget {
  final SignosVitales signos;

  const _Mediciones({required this.signos});

  @override
  Widget build(BuildContext context) {
    final fecha = signos.fecha;
    final presion = presionLegible(
      signos.presionSistolica,
      signos.presionDiastolica,
    );

    final datos = <(String, String)>[
      if (presion != null) ('Presión', presion),
      if (signos.pesoKg != null)
        ('Peso', '${numeroLegible(signos.pesoKg!)} kg'),
      if (signos.imc != null) ('IMC', numeroLegible(signos.imc!)),
      if (signos.glucemiaMgDl != null)
        ('Glucemia', '${numeroLegible(signos.glucemiaMgDl!)} mg/dL'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaSeccion(
          fecha == null
              ? 'Últimas mediciones'
              : 'Últimas mediciones · ${FormatoFecha.fechaMedia(fecha)}',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (rotulo, valor) in datos)
              Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tarjetaPlana,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.bordeCampo),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rotulo,
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valor,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Una consulta: cuándo, con quién y la modalidad; al abrirla, todo lo que
/// quedó de ella.
class _TarjetaAtencion extends StatelessWidget {
  final AtencionMiSalud atencion;
  final bool abierta;
  final VoidCallback alTocar;

  const _TarjetaAtencion({
    required this.atencion,
    required this.abierta,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final inicio = atencion.inicio;
    final modalidad = atencion.tipo.isEmpty
        ? null
        : EstiloDeCatalogo.de(
            context.catalogos,
            Catalogos.modalidadCita,
            atencion.tipo,
          );

    return TarjetaTranslucida(
      padding: EdgeInsets.zero,
      tinte: modalidad?.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('atencion-${atencion.id}'),
            onTap: alTocar,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(AppEspaciado.l),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inicio == null
                              ? 'Consulta'
                              : FormatoFecha.diaLargoConAnio(inicio),
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            atencion.medicoNombre,
                            atencion.especialidad,
                          ].where((p) => p.isNotEmpty).join(' · '),
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 12.5,
                          ),
                        ),
                        if (modalidad != null || atencion.enCurso) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (modalidad != null)
                                Pastilla(
                                  texto: modalidad.nombre,
                                  color: modalidad.color,
                                  icono: modalidad.icono,
                                ),
                              if (atencion.enCurso)
                                const Pastilla(
                                  texto: 'En curso',
                                  color: AppColors.alerta,
                                  icono: Icons.pending_outlined,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: abierta ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (abierta)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppEspaciado.l,
                0,
                AppEspaciado.l,
                AppEspaciado.l,
              ),
              child: _DetalleAtencion(atencion: atencion),
            ),
        ],
      ),
    );
  }
}

class _DetalleAtencion extends StatelessWidget {
  final AtencionMiSalud atencion;

  const _DetalleAtencion({required this.atencion});

  Future<void> _abrirReceta(BuildContext context, Receta receta) {
    final servicio = context.read<MiSaludCubit>().servicio;

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RecetaPage(id: receta.id, inicial: receta, servicio: servicio),
      ),
    );
  }

  Future<void> _abrirOrden(BuildContext context, Orden orden) {
    final servicio = context.read<MiSaludCubit>().servicio;

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OrdenPage(id: orden.id, inicial: orden, servicio: servicio),
      ),
    );
  }

  Future<void> _abrirCertificado(
    BuildContext context,
    CertificadoReposo certificado,
  ) {
    final servicio = context.read<MiSaludCubit>().servicio;

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CertificadoPage(
          id: certificado.id,
          inicial: certificado,
          servicio: servicio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final control = atencion.proximoControl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.bordeCampo, height: 1),
        const SizedBox(height: 14),
        if (atencion.enCurso) ...[
          const RecuadroAviso.informacion(
            'La consulta sigue abierta: por ahora ves lo que el médico ya '
            'firmó. El resto aparecerá cuando la cierre.',
            icono: Icons.pending_outlined,
          ),
          const SizedBox(height: 12),
        ],
        if (atencion.motivoConsulta.isNotEmpty)
          BloqueDeTexto(rotulo: 'Motivo', texto: atencion.motivoConsulta),
        if (atencion.diagnosticos.isNotEmpty) ...[
          const RotuloPequeno('Diagnósticos'),
          ListaDeDiagnosticos(diagnosticos: atencion.diagnosticos),
          const SizedBox(height: 12),
        ],
        if (atencion.plan.isNotEmpty)
          BloqueDeTexto(rotulo: 'Indicaciones', texto: atencion.plan),
        if (atencion.indicacionesNoFarmacologicas.isNotEmpty)
          BloqueDeTexto(
            rotulo: 'Recomendaciones',
            texto: atencion.indicacionesNoFarmacologicas,
          ),
        if (control != null) ...[
          RecuadroAviso.informacion(
            'Próximo control: ${FormatoFecha.diaLargoConAnio(control)}',
            icono: Icons.event_repeat_rounded,
          ),
          const SizedBox(height: 12),
        ],
        if (atencion.recetas.isNotEmpty) ...[
          const RotuloPequeno('Recetas'),
          const SizedBox(height: 6),
          for (final receta in atencion.recetas) ...[
            _FilaDocumento(
              key: Key('receta-${receta.id}'),
              icono: Icons.medication_outlined,
              titulo: receta.items.map((i) => i.nombreCompleto).join(', '),
              detalle: [
                for (final item in receta.items)
                  if (item.posologia.isNotEmpty)
                    '${item.medicamento}: ${item.posologia}',
              ].join('\n'),
              anulado: receta.anulada,
              firmado: receta.firmado,
              alTocar: () => _abrirReceta(context, receta),
              claveDelPdf: Key('pdf-receta-${receta.id}'),
              alVerPdf: receta.puedeVerPdf
                  ? () => abrirPdfDelDocumento(
                      context,
                      TipoDocumentoFirmado.receta,
                      receta,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
        ],
        if (atencion.certificados.isNotEmpty) ...[
          const RotuloPequeno('Certificados de reposo'),
          const SizedBox(height: 6),
          for (final certificado in atencion.certificados) ...[
            _FilaDocumento(
              key: Key('certificado-${certificado.id}'),
              icono: Icons.hotel_outlined,
              titulo: resumenDelReposo(certificado),
              detalle: _periodo(certificado),
              anulado: certificado.anulada,
              masculino: true,
              firmado: certificado.firmado,
              alTocar: () => _abrirCertificado(context, certificado),
              claveDelPdf: Key('pdf-certificado-${certificado.id}'),
              alVerPdf: certificado.puedeVerPdf
                  ? () => abrirPdfDelDocumento(
                      context,
                      TipoDocumentoFirmado.certificado,
                      certificado,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
        ],
        if (atencion.adjuntos.isNotEmpty) ...[
          const RotuloPequeno('Adjuntos'),
          const SizedBox(height: 6),
          for (final archivo in atencion.adjuntos) ...[
            FilaAdjunto(
              nombre: archivo.nombre,
              tamano: archivo.tamano,
              esImagen: archivo.esImagen,
              onTap: () => abrirArchivo(context, archivo),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
        ],
        if (atencion.ordenes.isNotEmpty) ...[
          const RotuloPequeno('Órdenes'),
          const SizedBox(height: 6),
          for (final orden in atencion.ordenes) ...[
            _FilaDocumento(
              key: Key('orden-${orden.id}'),
              icono: orden.tipo == TipoOrden.imagen
                  ? Icons.monitor_heart_outlined
                  : Icons.biotech_outlined,
              titulo:
                  '${nombreDelTipoDeOrden(orden.tipo)}: '
                  '${examenes(orden.items.length)}',
              detalle: orden.items.map((i) => i.nombre).join(', '),
              anulado: orden.anulada,
              urgente: orden.urgente,
              firmado: orden.firmado,
              alTocar: () => _abrirOrden(context, orden),
              claveDelPdf: Key('pdf-orden-${orden.id}'),
              alVerPdf: orden.puedeVerPdf
                  ? () => abrirPdfDelDocumento(
                      context,
                      TipoDocumentoFirmado.orden,
                      orden,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// «Del lunes 28 de septiembre al miércoles 30 de septiembre de 2026».
String _periodo(CertificadoReposo certificado) {
  final desde = certificado.fechaDesde;
  final hasta = certificado.fechaHasta;
  if (desde == null) return '';
  if (hasta == null || hasta == desde) {
    return 'El ${FormatoFecha.diaLargoConAnio(desde).toLowerCase()}';
  }

  return 'Del ${FormatoFecha.diaLargo(desde).toLowerCase()} al '
      '${FormatoFecha.diaLargoConAnio(hasta).toLowerCase()}';
}

/// Una receta, una orden o un certificado dentro de una consulta: se toca
/// para verlo entero. «Ver PDF» abre directo su PDF.
class _FilaDocumento extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool anulado;
  final bool urgente;
  final bool firmado;

  /// «Anulado», «Firmado»: un certificado; la receta y la orden, en
  /// femenino.
  final bool masculino;

  final VoidCallback alTocar;
  final VoidCallback? alVerPdf;
  final Key? claveDelPdf;

  const _FilaDocumento({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alTocar,
    this.anulado = false,
    this.urgente = false,
    this.firmado = false,
    this.masculino = false,
    this.alVerPdf,
    this.claveDelPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: anulado ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.campo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bordeCampo),
            ),
            child: Row(
              children: [
                Icon(icono, color: AppColors.acentoClaro, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (detalle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle,
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (anulado || urgente || firmado) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (anulado)
                              Pastilla(
                                texto: masculino ? 'Anulado' : 'Anulada',
                                color: AppColors.peligroSuave,
                                icono: Icons.block_rounded,
                              ),
                            if (urgente)
                              const Pastilla(
                                texto: 'Urgente',
                                color: AppColors.alerta,
                                icono: Icons.priority_high_rounded,
                              ),
                            if (firmado)
                              Pastilla(
                                texto: masculino
                                    ? 'Firmado electrónicamente'
                                    : 'Firmada electrónicamente',
                                color: AppColors.exito,
                                icono: Icons.verified_rounded,
                              ),
                          ],
                        ),
                      ],
                      if (alVerPdf != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          key: claveDelPdf,
                          onPressed: alVerPdf,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.acentoClaro,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Ver PDF',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
