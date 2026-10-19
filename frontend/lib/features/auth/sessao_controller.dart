import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/session_storage.dart';
import 'auth_repository.dart';
import 'usuario.dart';

/// Quem está logado. As rotas observam esta classe para decidir entre
/// as telas de login e as telas do app.
class SessaoController extends ChangeNotifier {
  final AuthRepository _auth;
  final SessionStorage _storage;
  final ApiClient _api;

  Usuario? _usuario;

  SessaoController(this._auth, this._storage, this._api) {
    _api.aoRecusarToken = sair;
  }

  Usuario? get usuario => _usuario;
  bool get logado => _usuario != null;

  Future<void> restaurar() async {
    SessaoSalva? salva;
    try {
      salva = await _storage.ler();
    } catch (_) {
      // Dado salvo ilegível: segue como deslogado.
    }
    if (salva == null) return;

    if (_tokenExpirado(salva.token)) {
      await _storage.limpar();
      return;
    }

    _ativar(salva.token, Usuario.fromJson(salva.usuario));
  }

  Future<void> entrar(String email, String senha) async {
    final login = await _auth.login(email, senha);
    await _storage.salvar(login.token, login.usuario.toJson());
    _ativar(login.token, login.usuario);
  }

  Future<void> sair() async {
    _api.token = null;
    _usuario = null;
    notifyListeners();
    await _storage.limpar();
  }

  void _ativar(String token, Usuario usuario) {
    _api.token = token;
    _usuario = usuario;
    notifyListeners();
  }

  // Só lê a validade (campo "exp"); quem confere a assinatura é o backend.
  static bool _tokenExpirado(String token) {
    try {
      final partes = token.split('.');
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(partes[1])),
      );
      final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'] as int;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } catch (_) {
      return true;
    }
  }
}
