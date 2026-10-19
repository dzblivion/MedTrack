import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/cadastro_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/recuperar_senha/nova_senha_screen.dart';
import '../features/auth/recuperar_senha/solicitar_codigo_screen.dart';
import '../features/auth/recuperar_senha/verificar_codigo_screen.dart';
import '../features/auth/sessao_controller.dart';
import '../features/home/home_screen.dart';
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
import '../widgets/em_construcao.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navegacao) => AppShell(navegacao: navegacao),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.inicio,
                builder: (context, state) => const HomeScreen(),
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
                builder: (context, state) =>
                    const EmConstrucao(titulo: 'Histórico'),
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
