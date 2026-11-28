import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/rotas.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/dados_cadastro.dart';
import 'package:frontend/features/auth/widgets/campo_codigo.dart';
import 'package:frontend/features/auth/sessao_controller.dart';
import 'package:frontend/features/auth/usuario.dart';
import 'package:frontend/features/compartilhamento/compartilhamento.dart';
import 'package:frontend/features/compartilhamento/compartilhamento_repository.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/doses/dose_repository.dart';
import 'package:frontend/features/lembretes/notificador.dart';
import 'package:frontend/features/lembretes/preferencias_lembretes.dart';
import 'package:frontend/features/mia/anuncio_premiado.dart';
import 'package:frontend/features/mia/digitalizar_prescricao_screen.dart';
import 'package:frontend/features/mia/medicamento_lido.dart';
import 'package:frontend/features/mia/mia_repository.dart';
import 'package:frontend/features/perfil/ajustar_foto_screen.dart';
import 'package:frontend/features/perfil/conta_repository.dart';
import 'package:frontend/features/perfil/escolher_foto.dart';
import 'package:frontend/features/perfil/foto_perfil_repository.dart';
import 'package:frontend/features/tratamentos/dados_tratamento.dart';
import 'package:frontend/features/tratamentos/frequencia.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';
import 'package:frontend/features/tratamentos/tratamento_repository.dart';
import 'package:frontend/main.dart';

const maria = Usuario(id: 1, nome: 'Maria', email: 'm@m.com');
const draAna = Usuario(
  id: 2,
  nome: 'Dra. Ana',
  email: 'ana@m.com',
  ehProfissional: true,
);

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

  /// E-mails para os quais o código de cadastro foi pedido.
  final codigosCadastro = <String>[];
  ApiException? erroCodigoCadastro;
  ApiException? erroCadastrar;
  ({Map<String, dynamic> json, bool profissional})? cadastro;
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
  Future<void> solicitarCodigoCadastro(String email) async {
    codigosCadastro.add(email);
    final falha = erroCodigoCadastro;
    if (falha != null) {
      erroCodigoCadastro = null;
      throw falha;
    }
  }

  @override
  Future<void> cadastrar(DadosCadastro dados, String codigo) async {
    if (erroCadastrar != null) throw erroCadastrar!;
    cadastro = (json: dados.toJson(codigo), profissional: dados.profissional != null);
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

/// Lista de tratamentos falsa. [erro] faz a próxima busca falhar.
class TratamentoFake extends TratamentoRepository {
  List<Tratamento> tratamentos;
  ApiException? erro;
  ApiException? erroSalvar;
  int buscas = 0;
  Map<String, dynamic>? criado;
  ({int id, Map<String, dynamic> dados})? atualizado;

  TratamentoFake([this.tratamentos = const []]) : super(ApiClient());

  final mudancasStatus = <StatusTratamento>[];
  int cancelamentos = 0;
  ApiException? erroBuscar;

  @override
  Future<Tratamento> buscar(int id) async {
    final falha = erroBuscar;
    if (falha != null) {
      erroBuscar = null;
      throw falha;
    }
    return tratamentos.firstWhere((t) => t.id == id);
  }

  @override
  Future<void> alterarStatus(int id, StatusTratamento status) async {
    mudancasStatus.add(status);
    _trocarStatus(id, status);
  }

  @override
  Future<void> cancelar(int id) async {
    cancelamentos++;
    _trocarStatus(id, StatusTratamento.cancelado);
  }

  void _trocarStatus(int id, StatusTratamento status) {
    tratamentos = [
      for (final t in tratamentos)
        t.id != id
            ? t
            : Tratamento(
                id: t.id,
                medicamento: t.medicamento,
                dosagemValor: t.dosagemValor,
                dosagemUnidade: t.dosagemUnidade,
                quantidadePorDose: t.quantidadePorDose,
                formaConsumo: t.formaConsumo,
                dataInicio: t.dataInicio,
                duracaoDias: t.duracaoDias,
                status: status,
                frequencia: t.frequencia,
              ),
    ];
  }

  @override
  Future<int?> criar(DadosTratamento dados) async {
    if (erroSalvar != null) throw erroSalvar!;
    criado = dados.toJson();
    return 99;
  }

  @override
  Future<void> atualizar(int id, DadosTratamento dados) async {
    if (erroSalvar != null) throw erroSalvar!;
    atualizado = (id: id, dados: dados.toJson());
  }

  @override
  Future<List<Tratamento>> listar() async {
    buscas++;
    final falha = erro;
    if (falha != null) {
      erro = null;
      throw falha;
    }
    return tratamentos;
  }
}

/// Doses falsas. [erro] faz a próxima busca falhar; registrar muda o status.
class DoseFake extends DoseRepository {
  List<Dose> doses;
  ApiException? erro;
  ApiException? erroRegistrar;
  int buscas = 0;
  final registros = <({int id, bool tomada})>[];

  DoseFake([this.doses = const []]) : super(ApiClient(), TratamentoFake());

  @override
  Future<List<Dose>> doDia(DateTime dia) async {
    buscas++;
    final falha = erro;
    if (falha != null) {
      erro = null;
      throw falha;
    }
    return doses;
  }

  /// Falha a próxima busca das doses de um tratamento (detalhe).
  ApiException? erroDoTratamento;

  /// Resposta de [primeiraPendente] (o aviso ao cadastrar).
  DateTime? primeiraDose;
  int? pediuPrimeiraDe;

  @override
  Future<DateTime?> primeiraPendente(int tratamentoId) async {
    pediuPrimeiraDe = tratamentoId;
    return primeiraDose;
  }

  @override
  Future<List<Dose>> doTratamento(Tratamento tratamento) async {
    final falha = erroDoTratamento;
    if (falha != null) {
      erroDoTratamento = null;
      throw falha;
    }
    return [for (final d in doses) if (d.tratamentoId == tratamento.id) d];
  }

  @override
  Future<List<Dose>> proximas(DateTime agora) async => [
    for (final d in doses)
      if (d.pendente && d.agendadaPara.isAfter(agora)) d,
  ]..sort((a, b) => a.agendadaPara.compareTo(b.agendadaPara));

  /// O histórico usa a mesma lista, da mais recente para a mais antiga.
  @override
  Future<List<Dose>> todas() async {
    final lista = await doDia(DateTime.now());
    return [...lista]..sort((a, b) => b.agendadaPara.compareTo(a.agendadaPara));
  }

  @override
  Future<void> registrar(int id, {required bool tomada}) async {
    if (erroRegistrar != null) throw erroRegistrar!;
    registros.add((id: id, tomada: tomada));
    doses = [
      for (final d in doses)
        d.id != id
            ? d
            : doseExemplo(
                id: d.id,
                tratamentoId: d.tratamentoId,
                medicamento: d.medicamento,
                em: d.agendadaPara,
                status: tomada ? StatusDose.tomada : StatusDose.naoTomada,
              ),
    ];
  }
}

Dose doseExemplo({
  int id = 1,
  int tratamentoId = 1,
  String medicamento = 'Amoxicilina',
  required DateTime em,
  StatusDose status = StatusDose.pendente,
}) =>
    Dose(
      id: id,
      tratamentoId: tratamentoId,
      medicamento: medicamento,
      detalhe: '500 mg · 1 por dose',
      agendadaPara: em,
      status: status,
    );

/// MIA falsa: devolve [resultado] ou lança [erro], e guarda o que recebeu.
class MiaFake extends MiaRepository {
  ResultadoMia resultado;
  ApiException? erro;
  final enviados = <String>[];

  MiaFake([this.resultado = const ResultadoMia(
    textoExtraido: '',
    medicamentos: [],
  )]) : super(ApiClient());

  @override
  Future<ResultadoMia> lerPrescricao({
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    enviados.add(nomeArquivo);
    final falha = erro;
    if (falha != null) {
      erro = null;
      throw falha;
    }
    return resultado;
  }
}

/// Anúncio falso: não mostra nada; [assistiu] decide a recompensa.
class AnuncioFake implements AnuncioPremiado {
  bool assistiu;
  int exibicoes = 0;

  AnuncioFake({this.assistiu = true});

  @override
  Future<bool> exibir(BuildContext context) async {
    exibicoes++;
    return assistiu;
  }
}

/// Foto de perfil falsa: guarda a foto em memória.
class FotoPerfilFake extends FotoPerfilRepository {
  Uint8List? foto;
  ApiException? erroEnviar;
  final enviadas = <String>[];
  int remocoes = 0;

  FotoPerfilFake([this.foto]) : super(ApiClient());

  @override
  Future<Uint8List?> buscar() async => foto;

  @override
  Future<void> enviar({required List<int> bytes, required String nome}) async {
    if (erroEnviar != null) throw erroEnviar!;
    enviadas.add(nome);
    foto = Uint8List.fromList(bytes);
  }

  @override
  Future<void> remover() async {
    remocoes++;
    foto = null;
  }
}

/// Compartilhamentos falsos, para os dois lados (paciente e profissional).
class CompartilhamentoFake extends CompartilhamentoRepository {
  // Paciente
  List<CompartilhamentoDoPaciente> doPaciente;
  List<PedidoDeAcesso> pedidos;
  String codigo = 'cod-abc123';
  final codigosGerados = <int>[];
  final decisoes = <({int id, bool aprovar})>[];
  final revogados = <int>[];

  // Profissional
  List<TratamentoDePaciente> doProfissional;
  Map<int, DetalheCompartilhado> detalhes;
  final codigosUsados = <String>[];
  ApiException? erroUsar;

  CompartilhamentoFake({
    this.doPaciente = const [],
    this.pedidos = const [],
    this.doProfissional = const [],
    this.detalhes = const {},
  }) : super(ApiClient());

  @override
  Future<String> gerarCodigo(int tratamentoId) async {
    codigosGerados.add(tratamentoId);
    return codigo;
  }

  @override
  Future<List<CompartilhamentoDoPaciente>> listarDoPaciente() async =>
      doPaciente;

  @override
  Future<List<PedidoDeAcesso>> pedidosPendentes() async => pedidos;

  @override
  Future<void> decidir(int compartilhamentoId, {required bool aprovar}) async {
    decisoes.add((id: compartilhamentoId, aprovar: aprovar));
    pedidos = [
      for (final p in pedidos)
        if (p.compartilhamentoId != compartilhamentoId) p,
    ];
    doPaciente = [
      for (final c in doPaciente)
        c.id != compartilhamentoId
            ? c
            : CompartilhamentoDoPaciente(
                id: c.id,
                tratamentoId: c.tratamentoId,
                medicamento: c.medicamento,
                profissional: c.profissional,
                status: aprovar
                    ? StatusCompartilhamento.ativo
                    : StatusCompartilhamento.recusado,
              ),
    ];
  }

  @override
  Future<void> revogar(int compartilhamentoId) async {
    revogados.add(compartilhamentoId);
    doPaciente = [
      for (final c in doPaciente)
        c.id != compartilhamentoId
            ? c
            : CompartilhamentoDoPaciente(
                id: c.id,
                tratamentoId: c.tratamentoId,
                medicamento: c.medicamento,
                profissional: c.profissional,
                status: StatusCompartilhamento.revogado,
              ),
    ];
  }

  @override
  Future<void> usarCodigo(String codigo) async {
    if (erroUsar != null) throw erroUsar!;
    codigosUsados.add(codigo.trim());
  }

  @override
  Future<List<TratamentoDePaciente>> listarDoProfissional() async =>
      doProfissional;

  @override
  Future<DetalheCompartilhado> buscar(int compartilhamentoId) async =>
      detalhes[compartilhamentoId]!;
}

const profissionalAna = ProfissionalResumo(
  nome: 'Dra. Ana',
  profissao: 'Médico(a)',
  registro: 'CRM 12345',
  uf: 'PB',
);

/// Notificações falsas: guarda o que foi agendado e mostrado.
class NotificadorFake implements Notificador {
  @override
  bool agendaNoAparelho;
  bool permite;
  bool? estadoPermissao;
  int pedidos = 0;
  final agendados =
      <int, ({DateTime quando, String titulo, String texto, String? dados})>{};
  final mostradas = <String>[];

  NotificadorFake({this.agendaNoAparelho = true, this.permite = true});

  @override
  Future<void> iniciar() async {}

  @override
  Future<bool> pedirPermissao() async {
    pedidos++;
    estadoPermissao = permite;
    return permite;
  }

  @override
  Future<bool?> permitido() async => estadoPermissao;

  @override
  Future<void> agendar({
    required int id,
    required DateTime quando,
    required String titulo,
    required String texto,
    String? dados,
  }) async => agendados[id] = (
    quando: quando,
    titulo: titulo,
    texto: texto,
    dados: dados,
  );

  @override
  Future<void> mostrarAgora({
    required String titulo,
    required String texto,
  }) async => mostradas.add(texto);

  @override
  Future<void> cancelar(int id) async => agendados.remove(id);

  @override
  Future<void> cancelarTodos() async => agendados.clear();
}

/// Preferências dos lembretes em memória.
class ArmazenamentoLembretesFake extends ArmazenamentoLembretes {
  PreferenciasLembretes salvas;

  ArmazenamentoLembretesFake([
    this.salvas = const PreferenciasLembretes(),
  ]);

  @override
  Future<PreferenciasLembretes> ler() async => salvas;

  @override
  Future<void> salvar(PreferenciasLembretes preferencias) async =>
      salvas = preferencias;
}

/// Conta falsa: troca o nome e "exclui" se a senha for [senhaCerta].
class ContaFake extends ContaRepository {
  String senhaCerta;
  ApiException? erroNome;
  final nomesSalvos = <String>[];
  int exclusoes = 0;

  ContaFake({this.senhaCerta = 'senha123'}) : super(ApiClient());

  @override
  Future<String> alterarNome(String nome) async {
    if (erroNome != null) throw erroNome!;
    nomesSalvos.add(nome);
    return nome.trim();
  }

  @override
  Future<void> excluir(String senha) async {
    if (senha != senhaCerta) {
      throw const ApiException('Senha incorreta!', 403);
    }
    exclusoes++;
  }
}

/// PNG de 1x1 pixel, para fotos de teste que a tela consegue mostrar.
final pngDeTeste = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8'
  'AAAAASUVORK5CYII=',
);

/// Tratamento de exemplo que começou há [diasAtras] dias.
Tratamento tratamentoExemplo({
  int id = 1,
  String medicamento = 'Amoxicilina',
  StatusTratamento status = StatusTratamento.ativo,
  int diasAtras = 0,
  int duracaoDias = 7,
  bool semDosagem = false,
  bool continuo = false,
  Frequencia? frequencia,
}) {
  final hoje = DateTime.now();
  return Tratamento(
    id: id,
    medicamento: medicamento,
    dosagemValor: semDosagem ? null : 500,
    dosagemUnidade: semDosagem ? null : 'mg',
    quantidadePorDose: 1,
    formaConsumo: 'oral',
    dataInicio: DateTime(hoje.year, hoje.month, hoje.day - diasAtras),
    duracaoDias: continuo ? null : duracaoDias,
    status: status,
    frequencia: frequencia,
  );
}

/// Um JWT com o "exp" pedido. A assinatura é falsa: o app não a confere.
String tokenFalso({required DateTime expiraEm}) {
  String parte(Map<String, Object> dados) =>
      base64Url.encode(utf8.encode(jsonEncode(dados))).replaceAll('=', '');

  final exp = expiraEm.millisecondsSinceEpoch ~/ 1000;
  return '${parte({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${parte({'usuario_id': 1, 'exp': exp})}.assinatura';
}

StorageMemoria storageComSessao(
  DateTime expiraEm, {
  Usuario usuario = maria,
}) => StorageMemoria((
  token: tokenFalso(expiraEm: expiraEm),
  usuario: usuario.toJson(),
));

/// Monta o app de verdade (rotas + providers), trocando só o backend e o armazenamento.
Future<SessaoController> abrirApp(
  WidgetTester tester, {
  AuthRepository? auth,
  ApiClient? api,
  StorageMemoria? storage,
  TratamentoRepository? tratamentos,
  DoseRepository? doses,
  MiaRepository? mia,
  AnuncioPremiado? anuncio,
  EscolherArquivo? escolherArquivo,
  FotoPerfilRepository? fotoPerfil,
  EscolherFoto? escolherFoto,
  AjustarFoto? ajustarFoto,
  CompartilhamentoRepository? compartilhamentos,
  ContaRepository? conta,
  Notificador? notificador,
  ArmazenamentoLembretes? armazenamentoLembretes,
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
      tratamentos: tratamentos ?? TratamentoFake(),
      doses: doses ?? DoseFake(),
      mia: mia ?? MiaFake(),
      anuncio: anuncio ?? AnuncioFake(),
      escolherArquivo: escolherArquivo ?? () async => null,
      fotoPerfil: fotoPerfil ?? FotoPerfilFake(),
      escolherFoto: escolherFoto ?? ({required camera}) async => null,
      // Por padrão, "ajustar" devolve a foto como veio (sem abrir a tela).
      ajustarFoto: ajustarFoto ?? (context, foto) async => foto,
      compartilhamentos: compartilhamentos ?? CompartilhamentoFake(),
      conta: conta ?? ContaFake(),
      notificador: notificador ?? NotificadorFake(),
      armazenamentoLembretes:
          armazenamentoLembretes ?? ArmazenamentoLembretesFake(),
      rotaInicial: rota,
    ),
  );
  await tester.pumpAndSettle();
  return sessao;
}

/// Digita no campo de código de 6 casinhas (o campo invisível por trás).
Future<void> digitarCodigo(WidgetTester tester, String codigo) => tester
    .enterText(
      find.descendant(
        of: find.byType(CampoCodigo),
        matching: find.byType(EditableText),
      ),
      codigo,
    );

Future<void> tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  await tester.ensureVisible(alvo);
  // Redesenha na posição rolada antes de tocar.
  await tester.pump();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}
