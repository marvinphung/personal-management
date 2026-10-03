import 'package:api_client/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStorage implements SessionStore {
  final FlutterSecureStorage _storage;
  final String _key;

  SecureSessionStorage({
    FlutterSecureStorage? storage,
    String key = 'qlt_session_token',
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _key = key;

  @override
  Future<void> saveToken(String token) => _storage.write(key: _key, value: token);

  @override
  Future<String?> getToken() => _storage.read(key: _key);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
