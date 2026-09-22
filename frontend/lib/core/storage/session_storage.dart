import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _chaveToken = 'token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> salvarToken(String token) =>
      _storage.write(key: _chaveToken, value: token);
}
