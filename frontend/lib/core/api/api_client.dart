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

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final resposta = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final dados = _decodificar(resposta.body);

      if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
        return dados;
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
