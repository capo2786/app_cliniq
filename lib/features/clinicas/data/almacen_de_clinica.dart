// lib/features/clinicas/data/almacen_de_clinica.dart

import 'dart:convert';

import '../../../core/storage/almacen_claves.dart';
import '../dominio/clinica.dart';

/// La última clínica, guardada en el teléfono.
///
/// No se borra al cerrar sesión: quien vuelve a entrar ve ya su clínica, con
/// la opción «Cambiar de clínica». Va en el llavero, como la sesión, aunque
/// no es un secreto: es el almacén de pares que ya existe y tiene su doble
/// en memoria para las pruebas.
class AlmacenDeClinica {
  static const String clave = 'cliniq_clinica_v1';

  final AlmacenClaves _almacen;

  const AlmacenDeClinica(this._almacen);

  /// La guardada, o `null` si no hay o no se puede leer.
  Future<Clinica?> leer() async {
    try {
      final texto = await _almacen.leer(clave);
      if (texto == null || texto.isEmpty) return null;

      return Clinica.desdeJson(jsonDecode(texto));
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(Clinica clinica) async {
    try {
      await _almacen.escribir(clave, jsonEncode(clinica.aJson()));
    } catch (_) {
      // Sin llavero la clínica vale mientras la aplicación esté abierta.
    }
  }

  Future<void> borrar() async {
    try {
      await _almacen.borrar(clave);
    } catch (_) {
      // Si el llavero no responde, tampoco se podrá leer.
    }
  }
}
