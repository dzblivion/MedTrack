import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;

  const ApiException(this.mensagem, [this.statusCode]);

  @override
  String toString() => mensagem;
}

class ApiClient {
  // 10.0.2.2 é como o emulador Android enxerga o localhost do computador.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://127.0.0.1:5000';
  }

  final http.Client _http;

  /// Enviado como `Authorization: Bearer` enquanto houver sessão.
  String? token;

  /// Chamado quando a API recusa o token (expirado ou inválido).
  VoidCallback? aoRecusarToken;

  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) =>
      _enviar('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _enviar('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _enviar('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _enviar('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _enviar('DELETE', path);

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final tokenEnviado = token;
    final requisicao = http.Request(
      metodo,
      Uri.parse('$baseUrl$path').replace(queryParameters: query),
    )..headers['Content-Type'] = 'application/json';

    if (tokenEnviado != null) {
      requisicao.headers['Authorization'] = 'Bearer $tokenEnviado';
    }
    if (body != null) requisicao.body = jsonEncode(body);

    try {
      final resposta = await http.Response.fromStream(
        await _http.send(requisicao).timeout(const Duration(seconds: 10)),
      );
      final dados = _decodificar(resposta.body);

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        return dados;
      }

      if (resposta.statusCode == 401 && tokenEnviado != null) {
        aoRecusarToken?.call();
        throw const ApiException('Sua sessão expirou. Entre novamente.', 401);
      }

      throw ApiException(
        dados['erro'] as String? ??
            'Erro inesperado no servidor (${resposta.statusCode}).',
        resposta.statusCode,
      );
    } on TimeoutException {
      throw const ApiException('O servidor demorou para responder.');
    } on http.ClientException {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }
  }

  Map<String, dynamic> _decodificar(String corpo) {
    try {
      final json = jsonDecode(corpo);
      return json is Map<String, dynamic> ? json : {};
    } on FormatException {
      return {};
    }
  }
}
