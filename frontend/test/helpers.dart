import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/sessao_controller.dart';
import 'package:frontend/features/auth/usuario.dart';
import 'package:frontend/main.dart';

const maria = Usuario(id: 1, nome: 'Maria', email: 'm@m.com');

/// Substitui o armazenamento seguro, que não existe no ambiente de testes.
class StorageMemoria extends SessionStorage {
  SessaoSalva? salva;

  StorageMemoria([this.salva]);

  @override
  Future<void> salvar(String token, Map<String, dynamic> usuario) async {
    salva = (token: token, usuario: usuario);
  }

  @override
  Future<SessaoSalva?> ler() async => salva;

  @override
  Future<void> limpar() async => salva = null;
}

/// Backend falso: registra as chamadas e devolve o que cada teste pedir.
class AuthFake extends AuthRepository {
  final Future<Login> Function()? respostaLogin;
  final ApiException? erroSolicitar;
  final ApiException? erroVerificar;

  int chamadasLogin = 0;
  bool chamouUsuario = false;
  bool chamouProfissional = false;
  int codigosSolicitados = 0;
  String? codigoVerificado;
  Map<String, String>? redefinicao;

  AuthFake({this.respostaLogin, this.erroSolicitar, this.erroVerificar})
      : super(ApiClient());

  @override
  Future<Login> login(String email, String senha) {
    chamadasLogin++;
    return respostaLogin!();
  }

  @override
  Future<void> cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
  }) async {
    chamouUsuario = true;
  }

  @override
  Future<void> cadastrarProfissional({
    required String nome,
    required String email,
    required String senha,
    required String profissao,
    required String registro,
    required String ufRegistro,
  }) async {
    chamouProfissional = true;
  }

  @override
  Future<void> solicitarCodigo(String email) async {
    codigosSolicitados++;
    if (erroSolicitar != null) throw erroSolicitar!;
  }

  @override
  Future<void> verificarCodigo(String email, String codigo) async {
    if (erroVerificar != null) throw erroVerificar!;
    codigoVerificado = codigo;
  }

  @override
  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    redefinicao = {'email': email, 'codigo': codigo, 'novaSenha': novaSenha};
  }
}

/// Um JWT com o "exp" pedido. A assinatura é falsa: o app não a confere.
String tokenFalso({required DateTime expiraEm}) {
  String parte(Map<String, Object> dados) =>
      base64Url.encode(utf8.encode(jsonEncode(dados))).replaceAll('=', '');

  final exp = expiraEm.millisecondsSinceEpoch ~/ 1000;
  return '${parte({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${parte({'usuario_id': 1, 'exp': exp})}.assinatura';
}

StorageMemoria storageComSessao(DateTime expiraEm) => StorageMemoria((
      token: tokenFalso(expiraEm: expiraEm),
      usuario: maria.toJson(),
    ));

/// Monta o app de verdade (rotas + providers), trocando só o backend e o armazenamento.
Future<SessaoController> abrirApp(
  WidgetTester tester, {
  AuthRepository? auth,
  ApiClient? api,
  StorageMemoria? storage,
  String rota = Rotas.splash,
}) async {
  final apiUsada = api ?? ApiClient();
  final authUsado = auth ?? AuthFake();
  final sessao = SessaoController(
    authUsado,
    storage ?? StorageMemoria(),
    apiUsada,
  );
  await sessao.restaurar();

  await tester.pumpWidget(
    MedTrackApp(
      api: apiUsada,
      auth: authUsado,
      sessao: sessao,
      rotaInicial: rota,
    ),
  );
  await tester.pumpAndSettle();
  return sessao;
}

Future<void> tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}
