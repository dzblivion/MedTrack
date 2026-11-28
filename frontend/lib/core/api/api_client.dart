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
  /// Endereço escolhido ao rodar/compilar, ex.:
  /// `flutter run --dart-define=API_URL=http://localhost:5000` (celular
  /// pelo cabo, com `adb reverse`) ou o endereço do servidor na nuvem.
  static const _apiUrl = String.fromEnvironment('API_URL');

  // 10.0.2.2 é como o emulador Android enxerga o localhost do computador.
  static String get baseUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
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

  /// Envia um arquivo (ex.: foto da receita) como formulário multipart.
  /// [espera] é maior que o padrão porque o processamento pode demorar.
  Future<Map<String, dynamic>> enviarArquivo(
    String path, {
    required String campo,
    required List<int> bytes,
    required String nomeArquivo,
    String metodo = 'POST',
    Duration espera = const Duration(seconds: 60),
  }) {
    final requisicao = http.MultipartRequest(metodo, Uri.parse('$baseUrl$path'))
      ..files.add(
        http.MultipartFile.fromBytes(campo, bytes, filename: nomeArquivo),
      );
    return _executar(requisicao, espera);
  }

  /// Baixa um arquivo (ex.: a foto de perfil). Nulo se não existir (404).
  Future<Uint8List?> baixar(String path) async {
    final resposta = await _responder(
      http.Request('GET', Uri.parse('$baseUrl$path')),
      const Duration(seconds: 15),
    );
    if (resposta.statusCode == 404) return null;
    _confirmarSucesso(resposta);
    return resposta.bodyBytes;
  }

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    final requisicao = http.Request(
      metodo,
      Uri.parse('$baseUrl$path').replace(queryParameters: query),
    )..headers['Content-Type'] = 'application/json';
    if (body != null) requisicao.body = jsonEncode(body);
    return _executar(requisicao, const Duration(seconds: 10));
  }

  /// Envia e devolve o JSON da resposta; erros viram [ApiException] com a
  /// mensagem do backend.
  Future<Map<String, dynamic>> _executar(
    http.BaseRequest requisicao,
    Duration espera,
  ) async {
    final resposta = await _responder(requisicao, espera);
    _confirmarSucesso(resposta);
    return _decodificar(resposta.body);
  }

  /// Envia com o token e trata o tempo de espera e a falta de conexão.
  Future<http.Response> _responder(
    http.BaseRequest requisicao,
    Duration espera,
  ) async {
    final tokenEnviado = token;
    if (tokenEnviado != null) {
      requisicao.headers['Authorization'] = 'Bearer $tokenEnviado';
    }

    try {
      final resposta = await http.Response.fromStream(
        await _http.send(requisicao).timeout(espera),
      );
      if (resposta.statusCode == 401 && tokenEnviado != null) {
        aoRecusarToken?.call();
        throw const ApiException('Sua sessão expirou. Entre novamente.', 401);
      }
      return resposta;
    } on TimeoutException {
      throw const ApiException('O servidor demorou para responder.');
    } on http.ClientException {
      throw const ApiException('Não foi possível conectar ao servidor.');
    }
  }

  void _confirmarSucesso(http.Response resposta) {
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return;
    throw ApiException(
      _decodificar(resposta.body)['erro'] as String? ??
          'Erro inesperado no servidor (${resposta.statusCode}).',
      resposta.statusCode,
    );
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
