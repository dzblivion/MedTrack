import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/rotas.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/sessao_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final auth = AuthRepository(api);
  final sessao = SessaoController(auth, SessionStorage(), api);
  await sessao.restaurar();

  runApp(MedTrackApp(api: api, auth: auth, sessao: sessao));
}

class MedTrackApp extends StatefulWidget {
  final ApiClient api;
  final AuthRepository auth;
  final SessaoController sessao;
  final String rotaInicial;

  const MedTrackApp({
    super.key,
    required this.api,
    required this.auth,
    required this.sessao,
    this.rotaInicial = Rotas.splash,
  });

  @override
  State<MedTrackApp> createState() => _MedTrackAppState();
}

class _MedTrackAppState extends State<MedTrackApp> {
  late final GoRouter _router = criarRouter(
    widget.sessao,
    rotaInicial: widget.rotaInicial,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        Provider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.sessao),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MedTrack',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
