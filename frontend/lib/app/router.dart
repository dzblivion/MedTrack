import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/mudancas.dart';
import '../features/auth/cadastro_screen.dart';
import '../features/compartilhamento/adicionar_paciente_screen.dart';
import '../features/compartilhamento/compartilhamento_repository.dart';
import '../features/compartilhamento/compartilhamentos_screen.dart';
import '../features/compartilhamento/pacientes_controller.dart';
import '../features/compartilhamento/pacientes_screen.dart';
import '../features/compartilhamento/pedidos_controller.dart';
import '../features/compartilhamento/tratamento_de_paciente_screen.dart';
import '../features/auth/confirmar_cadastro_screen.dart';
import '../features/auth/dados_cadastro.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/recuperar_senha/nova_senha_screen.dart';
import '../features/auth/recuperar_senha/solicitar_codigo_screen.dart';
import '../features/auth/recuperar_senha/verificar_codigo_screen.dart';
import '../features/auth/sessao_controller.dart';
import '../features/doses/dose_repository.dart';
import '../features/home/home_controller.dart';
import '../features/historico/historico_controller.dart';
import '../features/historico/historico_screen.dart';
import '../features/historico/historico_tratamento_screen.dart';
import '../features/home/home_screen.dart';
import '../features/mia/digitalizar_prescricao_screen.dart';
import '../features/mia/medicamento_lido.dart';
import '../features/mia/plus_screen.dart';
import '../features/mia/resultado_mia_screen.dart';
import '../features/perfil/perfil_screen.dart';
import '../features/perfil/texto_legal_screen.dart';
import '../features/perfil/textos_legais.dart';
import '../features/splash/splash_screen.dart';
import '../features/tratamentos/tratamento.dart';
import '../features/tratamentos/tratamento_detalhe_screen.dart';
import '../features/tratamentos/tratamento_form_screen.dart';
import '../features/tratamentos/tratamento_repository.dart';
import '../features/tratamentos/tratamentos_controller.dart';
import '../features/tratamentos/tratamentos_screen.dart';
import 'app_shell.dart';
import 'rotas.dart';

/// Só para quem não está logado; logado, quem tenta abri-las vai para o Início.
const _soSemLogin = [Rotas.splash, Rotas.login, Rotas.cadastro];

/// Abertas com ou sem login. A troca de senha do Perfil reaproveita a
/// recuperação por código.
const _abertas = [Rotas.recuperarSenha, Rotas.termos, Rotas.privacidade];

GoRouter criarRouter(
  SessaoController sessao, {
  String rotaInicial = Rotas.splash,
}) {
  // Telas abertas com esta chave ficam por cima do menu inferior.
  final raiz = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: raiz,
    initialLocation: rotaInicial,
    refreshListenable: sessao,
    redirect: (context, state) {
      final local = state.matchedLocation;
      if (_abertas.any(local.startsWith)) return null;

      final semLogin = _soSemLogin.any(local.startsWith);
      if (!sessao.logado && !semLogin) return Rotas.login;
      if (sessao.logado && semLogin) return Rotas.inicio;
      return null;
    },
    routes: [
      GoRoute(
        path: Rotas.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Rotas.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Rotas.cadastro,
        builder: (context, state) => const CadastroScreen(),
      ),
      // Sem os dados do cadastro (ex.: página recarregada), recomeça por ele.
      GoRoute(
        path: Rotas.confirmarCadastro,
        redirect: (context, state) =>
            state.extra is DadosCadastro ? null : Rotas.cadastro,
        builder: (context, state) =>
            ConfirmarCadastroScreen(dados: state.extra as DadosCadastro),
      ),
      GoRoute(
        path: Rotas.recuperarSenha,
        builder: (context, state) => SolicitarCodigoScreen(
          emailInicial: state.extra is String ? state.extra as String : '',
        ),
      ),
      // Sem os dados do passo anterior (ex.: página recarregada), recomeça o fluxo.
      GoRoute(
        path: Rotas.verificarCodigo,
        redirect: (context, state) =>
            state.extra is String ? null : Rotas.recuperarSenha,
        builder: (context, state) =>
            VerificarCodigoScreen(email: state.extra as String),
      ),
      GoRoute(
        path: Rotas.novaSenha,
        redirect: (context, state) =>
            state.extra is DadosNovaSenha ? null : Rotas.recuperarSenha,
        builder: (context, state) =>
            NovaSenhaScreen(dados: state.extra as DadosNovaSenha),
      ),
      GoRoute(
        path: Rotas.termos,
        builder: (context, state) => const TextoLegalScreen(
          titulo: 'Termos de uso',
          secoes: termosDeUso,
        ),
      ),
      GoRoute(
        path: Rotas.privacidade,
        builder: (context, state) => const TextoLegalScreen(
          titulo: 'Privacidade e dados',
          secoes: politicaDePrivacidade,
        ),
      ),
      // MIA: telas inteiras, por cima do menu (precisam de login).
      GoRoute(
        path: Rotas.mia,
        builder: (context, state) => DigitalizarPrescricaoScreen(
          escolherArquivo: context.read<EscolherArquivo>(),
        ),
      ),
      // Sem a leitura (ex.: página recarregada), volta para a câmera.
      GoRoute(
        path: Rotas.miaResultado,
        redirect: (context, state) =>
            state.extra is ResultadoMia ? null : Rotas.mia,
        builder: (context, state) =>
            ResultadoMiaScreen(resultado: state.extra as ResultadoMia),
      ),
      // Com um remédio lido, o formulário vem preenchido; sem, fica vazio
      // ("Cadastrar manualmente").
      GoRoute(
        path: Rotas.miaRevisar,
        builder: (context, state) => TratamentoFormScreen(
          sugestao: state.extra is MedicamentoLido
              ? state.extra as MedicamentoLido
              : null,
        ),
      ),
      GoRoute(
        path: Rotas.plus,
        builder: (context, state) => const PlusScreen(),
      ),
      GoRoute(
        path: Rotas.compartilhamentos,
        builder: (context, state) => const CompartilhamentosScreen(),
      ),
      // Telas do profissional, por cima do menu.
      GoRoute(
        path: Rotas.adicionarPaciente,
        builder: (context, state) => const AdicionarPacienteScreen(),
      ),
      GoRoute(
        path: '/pacientes/:id',
        redirect: (context, state) =>
            _idDaRota(state) == null ? Rotas.inicio : null,
        builder: (context, state) =>
            TratamentoDePacienteScreen(compartilhamentoId: _idDaRota(state)!),
      ),
      StatefulShellRoute.indexedStack(
        // Os controllers das abas ficam acima do menu para o menu poder
        // recarregá-los ao abrir a aba (ex.: depois de cadastrar um
        // tratamento). O Histórico só busca os dados quando aberto. Cada um
        // só carrega para o tipo de conta que o usa.
        builder: (context, state, navegacao) {
          final profissional = sessao.usuario?.ehProfissional == true;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) {
                  final home = HomeController(
                    context.read<DoseRepository>(),
                    mudancas: context.read<Mudancas>(),
                  );
                  if (!profissional) home.carregar();
                  return home;
                },
              ),
              ChangeNotifierProvider(
                create: (context) => HistoricoController(
                  context.read<DoseRepository>(),
                  mudancas: context.read<Mudancas>(),
                ),
              ),
              ChangeNotifierProvider(
                create: (context) {
                  final pedidos = PedidosController(
                    context.read<CompartilhamentoRepository>(),
                    mudancas: context.read<Mudancas>(),
                  );
                  if (!profissional) pedidos.carregar();
                  return pedidos;
                },
              ),
              ChangeNotifierProvider(
                create: (context) {
                  final pacientes = PacientesController(
                    context.read<CompartilhamentoRepository>(),
                  );
                  if (profissional) pacientes.carregar();
                  return pacientes;
                },
              ),
            ],
            child: AppShell(navegacao: navegacao, profissional: profissional),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              // O profissional não tem tratamentos próprios: o Início dele
              // é a lista de pacientes.
              GoRoute(
                path: Rotas.inicio,
                builder: (context, state) =>
                    sessao.usuario?.ehProfissional == true
                    ? const PacientesScreen()
                    : const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.tratamentos,
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => TratamentosController(
                    context.read<TratamentoRepository>(),
                    mudancas: context.read<Mudancas>(),
                  )..carregar(),
                  child: const TratamentosScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: raiz,
                    builder: (context, state) => const TratamentoFormScreen(),
                  ),
                  // Sem o tratamento (ex.: página recarregada), volta para a lista.
                  GoRoute(
                    path: ':id/editar',
                    parentNavigatorKey: raiz,
                    redirect: (context, state) =>
                        state.extra is Tratamento ? null : Rotas.tratamentos,
                    builder: (context, state) => TratamentoFormScreen(
                      original: state.extra as Tratamento,
                    ),
                  ),
                  // Histórico só deste tratamento, por cima do detalhe.
                  GoRoute(
                    path: ':id/historico',
                    parentNavigatorKey: raiz,
                    redirect: (context, state) =>
                        _idDaRota(state) == null ? Rotas.tratamentos : null,
                    builder: (context, state) => ChangeNotifierProvider(
                      create: (context) =>
                          HistoricoController(context.read<DoseRepository>())
                            ..filtrar(_idDaRota(state))
                            ..carregar(),
                      child: HistoricoTratamentoScreen(
                        medicamento: state.extra is String
                            ? state.extra as String
                            : null,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: raiz,
                    redirect: (context, state) =>
                        _idDaRota(state) == null ? Rotas.tratamentos : null,
                    builder: (context, state) =>
                        TratamentoDetalheScreen(id: _idDaRota(state)!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.historico,
                builder: (context, state) => const HistoricoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.perfil,
                builder: (context, state) => const PerfilScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

int? _idDaRota(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');
