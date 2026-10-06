import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';

void main() {
  late http.Request ultimaRequisicao;

  ApiClient clienteQueResponde(int status, String corpo) {
    return ApiClient(
      client: MockClient((requisicao) async {
        ultimaRequisicao = requisicao;
        return http.Response(corpo, status);
      }),
    );
  }

  test('com sessão, envia o token no cabeçalho', () async {
    final api = clienteQueResponde(200, '{"tratamentos": []}')..token = 'abc';

    await api.get('/tratamentos');

    expect(ultimaRequisicao.headers['Authorization'], 'Bearer abc');
  });

  test('sem sessão, não envia o cabeçalho de token', () async {
    final api = clienteQueResponde(200, '{}');

    await api.post('/login', {'email': 'm@m.com', 'senha': '12345678'});

    expect(ultimaRequisicao.headers.containsKey('Authorization'), isFalse);
  });

  test('envia os filtros na URL', () async {
    final api = clienteQueResponde(200, '{}')..token = 'abc';

    await api.get('/tratamentos', query: {'status': 'ativo'});

    expect(ultimaRequisicao.url.path, '/tratamentos');
    expect(ultimaRequisicao.url.queryParameters['status'], 'ativo');
  });

  test('token recusado (401) avisa a sessão e pede novo login', () async {
    var avisou = false;
    final api = clienteQueResponde(401, '{"erro": "Token inválido!"}')
      ..token = 'vencido'
      ..aoRecusarToken = () => avisou = true;

    await expectLater(
      api.get('/tratamentos'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensagem,
          'mensagem',
          'Sua sessão expirou. Entre novamente.',
        ),
      ),
    );
    expect(avisou, isTrue);
  });

  test('401 sem sessão (senha errada) mostra a mensagem do backend', () async {
    var avisou = false;
    final api = clienteQueResponde(401, '{"erro": "E-mail ou senha incorretos!"}')
      ..aoRecusarToken = () => avisou = true;

    await expectLater(
      api.post('/login', {'email': 'm@m.com', 'senha': 'errada'}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensagem,
          'mensagem',
          'E-mail ou senha incorretos!',
        ),
      ),
    );
    expect(avisou, isFalse);
  });
}
