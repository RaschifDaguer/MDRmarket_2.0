import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión cifrado en el teléfono.
abstract class TokenStorage {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> borrar();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _clave = 'auth_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> leer() => _storage.read(key: _clave);

  @override
  Future<void> guardar(String token) => _storage.write(key: _clave, value: token);

  @override
  Future<void> borrar() => _storage.delete(key: _clave);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
