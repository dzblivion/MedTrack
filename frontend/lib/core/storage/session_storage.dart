import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef SessaoSalva = ({String token, Map<String, dynamic> usuario});

class SessionStorage {
  static const _chaveToken = 'token';
  static const _chaveUsuario = 'usuario';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> salvar(String token, Map<String, dynamic> usuario) async {
    await _storage.write(key: _chaveToken, value: token);
    await _storage.write(key: _chaveUsuario, value: jsonEncode(usuario));
  }

  Future<SessaoSalva?> ler() async {
    final token = await _storage.read(key: _chaveToken);
    final usuario = await _storage.read(key: _chaveUsuario);
    if (token == null || usuario == null) return null;

    return (
      token: token,
      usuario: jsonDecode(usuario) as Map<String, dynamic>,
    );
  }

  Future<void> limpar() async {
    await _storage.delete(key: _chaveToken);
    await _storage.delete(key: _chaveUsuario);
  }
}
