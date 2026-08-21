import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum jetonunu saklayan katman. Testlerin platform kanalına ihtiyaç
/// duymaması için arayüz.
abstract class AuthStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Jeton Keychain'de duruyor — `shared_preferences` düz metin yazıyor ve
/// cihaz yedeğinden okunabiliyor.
class SecureAuthStore implements AuthStore {
  const SecureAuthStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'sepet_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Yalnızca testler için — süreç belleğinde tutar.
class MemoryAuthStore implements AuthStore {
  MemoryAuthStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
