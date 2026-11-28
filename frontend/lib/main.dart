import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/rotas.dart';
import 'app/router.dart';
import 'core/api/api_client.dart';
import 'core/mudancas.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/sessao_controller.dart';
import 'features/compartilhamento/compartilhamento_repository.dart';
import 'features/doses/dose_repository.dart';
import 'features/lembretes/lembretes_controller.dart';
import 'features/lembretes/notificador.dart';
import 'features/lembretes/preferencias_lembretes.dart';
import 'features/lembretes/segundo_plano.dart';
import 'features/mia/anuncio_premiado.dart';
import 'features/mia/digitalizar_prescricao_screen.dart';
import 'features/mia/mia_repository.dart';
import 'features/perfil/ajustar_foto_screen.dart';
import 'features/perfil/escolher_foto.dart';
import 'features/perfil/foto_perfil_controller.dart';
import 'features/perfil/foto_perfil_repository.dart';
import 'features/tratamentos/tratamento_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final auth = AuthRepository(api);
  final sessao = SessaoController(auth, SessionStorage(), api);
  final tratamentos = TratamentoRepository(api);
  await sessao.restaurar();

  runApp(
    MedTrackApp(
      api: api,
      auth: auth,
      sessao: sessao,
      tratamentos: tratamentos,
      doses: DoseRepository(api, tratamentos),
    ),
  );
}

class MedTrackApp extends StatefulWidget {
  final ApiClient api;
  final AuthRepository auth;
  final SessaoController sessao;
  final TratamentoRepository tratamentos;
  final DoseRepository doses;

  /// Opcionais: sem eles, usa os de verdade (os testes passam falsos).
  final MiaRepository? mia;
  final AnuncioPremiado? anuncio;
  final EscolherArquivo? escolherArquivo;
  final CompartilhamentoRepository? compartilhamentos;
  final FotoPerfilRepository? fotoPerfil;
  final EscolherFoto? escolherFoto;
  final AjustarFoto? ajustarFoto;
  final Notificador? notificador;
  final ArmazenamentoLembretes? armazenamentoLembretes;
  final String rotaInicial;

  const MedTrackApp({
    super.key,
    required this.api,
    required this.auth,
    required this.sessao,
    required this.tratamentos,
    required this.doses,
    this.mia,
    this.anuncio,
    this.escolherArquivo,
    this.compartilhamentos,
    this.fotoPerfil,
    this.escolherFoto,
    this.ajustarFoto,
    this.notificador,
    this.armazenamentoLembretes,
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
  final _mudancas = Mudancas();
  late final _mia = widget.mia ?? MiaRepository(widget.api);
  late final _compartilhamentos =
      widget.compartilhamentos ?? CompartilhamentoRepository(widget.api);
  late final AnuncioPremiado _anuncio =
      widget.anuncio ?? const AnuncioSimulado();
  late final _fotoPerfil = FotoPerfilController(
    widget.fotoPerfil ?? FotoPerfilRepository(widget.api),
    widget.sessao,
  );
  late final _lembretes = LembretesController(
    widget.notificador ?? NotificadorLocal(),
    widget.armazenamentoLembretes ?? ArmazenamentoLembretes(),
    widget.doses,
    widget.sessao,
    mudancas: _mudancas,
  )..iniciar();

  /// Ao voltar para o app, refaz os lembretes (podem ter surgido doses).
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: _lembretes.appVoltou);
    // Dose marcada pelos botões da notificação: Início e Histórico
    // atualizam. (Só com as notificações de verdade; os testes usam falsas.)
    if (widget.notificador == null) {
      ouvirDosesRegistradas(_mudancas.tratamentosMudaram);
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    if (widget.notificador == null) pararDeOuvirDosesRegistradas();
    _router.dispose();
    _lembretes.dispose();
    _mudancas.dispose();
    _fotoPerfil.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        Provider.value(value: widget.auth),
        Provider.value(value: widget.tratamentos),
        Provider.value(value: widget.doses),
        Provider.value(value: _mia),
        Provider.value(value: _compartilhamentos),
        Provider.value(value: _anuncio),
        Provider<EscolherArquivo>.value(
          value: widget.escolherArquivo ?? escolherArquivoDoAparelho,
        ),
        Provider<EscolherFoto>.value(
          value: widget.escolherFoto ?? escolherFotoDoAparelho,
        ),
        Provider<AjustarFoto>.value(
          value: widget.ajustarFoto ?? ajustarFotoNaTela,
        ),
        ChangeNotifierProvider.value(value: _fotoPerfil),
        ChangeNotifierProvider.value(value: _lembretes),
        // As telas só leem (read) e escutam por conta própria, então o
        // aviso não redesenha o app inteiro.
        ChangeNotifierProvider.value(value: _mudancas),
        ChangeNotifierProvider.value(value: widget.sessao),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MedTrack',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        // No navegador, o Flutter só deixa arrastar a tela com o dedo. Com
        // isso o mouse também arrasta (ex.: puxar para baixo para atualizar).
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        // Calendário, botões e textos prontos do Flutter em português.
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}
