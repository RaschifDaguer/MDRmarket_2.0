import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preferencias que se guardan en el teléfono (no en la API): el tema y las
/// búsquedas recientes. Si el almacenamiento falla, la app sigue igual.
abstract class Preferencias {
  Future<String?> leer(String clave);
  Future<void> guardar(String clave, String valor);
}

class PreferenciasSeguras implements Preferencias {
  const PreferenciasSeguras([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer(String clave) async {
    try {
      return await _storage.read(key: 'pref_$clave');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(String clave, String valor) async {
    try {
      await _storage.write(key: 'pref_$clave', value: valor);
    } catch (_) {
      // Sin almacenamiento (ej. navegador en modo privado): solo dura esta sesión.
    }
  }
}

/// En memoria (pruebas).
class PreferenciasEnMemoria implements Preferencias {
  PreferenciasEnMemoria([Map<String, String>? inicial]) : datos = {...?inicial};

  final Map<String, String> datos;

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> guardar(String clave, String valor) async => datos[clave] = valor;
}

final preferenciasProvider = Provider<Preferencias>((ref) => const PreferenciasSeguras());

/// Tema elegido en Cuenta: el del sistema (por defecto), claro u oscuro.
class ModoTema extends Notifier<ThemeMode> {
  static const _clave = 'tema';

  @override
  ThemeMode build() {
    _cargar();
    return ThemeMode.system;
  }

  Future<void> _cargar() async {
    final guardado = await ref.read(preferenciasProvider).leer(_clave);
    final modo = ThemeMode.values.where((m) => m.name == guardado).firstOrNull;
    if (modo != null && ref.mounted) state = modo;
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    await ref.read(preferenciasProvider).guardar(_clave, modo.name);
  }
}

final modoTemaProvider = NotifierProvider<ModoTema, ThemeMode>(ModoTema.new);

/// Últimas búsquedas del cliente (máximo 6, la más nueva primero).
class BusquedasRecientes extends Notifier<List<String>> {
  static const _clave = 'busquedas';
  static const maximo = 6;

  @override
  List<String> build() {
    _cargar();
    return const [];
  }

  Future<void> _cargar() async {
    final guardado = await ref.read(preferenciasProvider).leer(_clave);
    if (guardado != null && guardado.isNotEmpty && ref.mounted) {
      state = guardado.split('\n').where((b) => b.isNotEmpty).take(maximo).toList();
    }
  }

  Future<void> agregar(String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return;
    state = [limpio, ...state.where((b) => b.toLowerCase() != limpio.toLowerCase())].take(maximo).toList();
    await ref.read(preferenciasProvider).guardar(_clave, state.join('\n'));
  }

  Future<void> borrar() async {
    state = const [];
    await ref.read(preferenciasProvider).guardar(_clave, '');
  }
}

final busquedasRecientesProvider = NotifierProvider<BusquedasRecientes, List<String>>(BusquedasRecientes.new);
