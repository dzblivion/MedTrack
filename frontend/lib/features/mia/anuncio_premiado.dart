import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Anúncio "premiado": a pessoa assiste e ganha uma análise da MIA.
/// Devolve `true` só se assistiu até o fim.
///
/// Hoje o app usa o [AnuncioSimulado] (funciona em qualquer lugar, inclusive
/// no navegador). No celular, uma versão com o Google AdMob entra no lugar
/// sem mudar as telas.
abstract class AnuncioPremiado {
  Future<bool> exibir(BuildContext context);
}

class AnuncioSimulado implements AnuncioPremiado {
  final int segundos;

  const AnuncioSimulado({this.segundos = 5});

  @override
  Future<bool> exibir(BuildContext context) async {
    final assistiu = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AnuncioSimuladoScreen(segundos: segundos),
      ),
    );
    return assistiu ?? false;
  }
}

/// Tela cheia imitando um anúncio, com contagem regressiva.
class AnuncioSimuladoScreen extends StatefulWidget {
  final int segundos;

  const AnuncioSimuladoScreen({super.key, required this.segundos});

  @override
  State<AnuncioSimuladoScreen> createState() => _AnuncioSimuladoScreenState();
}

class _AnuncioSimuladoScreenState extends State<AnuncioSimuladoScreen> {
  late int _restante = widget.segundos;
  Timer? _contagem;

  @override
  void initState() {
    super.initState();
    _contagem = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _restante--);
      if (_restante <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _contagem?.cancel();
    super.dispose();
  }

  bool get _terminou => _restante <= 0;

  @override
  Widget build(BuildContext context) {
    const branco = TextStyle(fontFamily: 'Poppins', color: Colors.white);

    // Sair antes do fim (voltar do celular) não dá a recompensa.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) Navigator.of(context).pop(_terminou);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111A1C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Anúncio',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_terminou)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Fechar anúncio',
                        onPressed: () => Navigator.of(context).pop(true),
                      )
                    else
                      Text(
                        'Recompensa em ${_restante}s',
                        style: branco.copyWith(fontSize: 12),
                      ),
                  ],
                ),
                const Spacer(),
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.ciano,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  'MedTrack Plus',
                  style: branco.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digitalize suas receitas com a MIA\nsem assistir a anúncios.',
                  textAlign: TextAlign.center,
                  style: branco.copyWith(fontSize: 14, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  'Anúncio de demonstração',
                  style: branco.copyWith(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
