import 'package:go_router/go_router.dart';

import '../features/auth/cadastro_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/recuperar_senha/nova_senha_screen.dart';
import '../features/auth/recuperar_senha/solicitar_codigo_screen.dart';
import '../features/auth/recuperar_senha/verificar_codigo_screen.dart';
import '../features/auth/sessao_controller.dart';
import '../features/home/home_screen.dart';
import '../features/perfil/perfil_screen.dart';
import '../features/splash/splash_screen.dart';
import '../widgets/em_construcao.dart';
import 'app_shell.dart';
import 'rotas.dart';

/// Telas acessíveis sem login. Logado, quem tenta abri-las vai para o Início.
const _rotasPublicas = [
  Rotas.splash,
  Rotas.login,
  Rotas.cadastro,
  Rotas.recuperarSenha,
];

GoRouter criarRouter(
  SessaoController sessao, {
  String rotaInicial = Rotas.splash,
}) {
  return GoRouter(
    initialLocation: rotaInicial,
    refreshListenable: sessao,
    redirect: (context, state) {
      final publica = _rotasPublicas.any(state.matchedLocation.startsWith);
      if (!sessao.logado && !publica) return Rotas.login;
      if (sessao.logado && publica) return Rotas.inicio;
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
                builder: (context, state) =>
                    const EmConstrucao(titulo: 'Tratamentos'),
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
