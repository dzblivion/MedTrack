import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/botao_cabecalho.dart';
import '../../widgets/cabecalho_usuario.dart';
import '../auth/sessao_controller.dart';
import '../doses/dose.dart';
import 'home_controller.dart';
import 'widgets/card_adesao.dart';
import 'widgets/card_doses_do_dia.dart';
import 'widgets/card_mia.dart';
import 'widgets/card_proxima_dose.dart';

/// Início: próxima dose, adesão do dia e o convite da MIA.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // A MIA (ler a prescrição) depende das chaves da Azure e do Gemini.
  static void _emBreve(BuildContext context) => AppSnackBar.info(
        context,
        'A leitura de prescrição pela MIA chega em breve.',
      );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final nome = context.watch<SessaoController>().usuario?.nome ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CabecalhoUsuario(
              nome: nome,
              acao: BotaoCabecalho(
                texto: 'Nova prescrição',
                onPressed: () => _emBreve(context),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              'Seu tratamento de hoje:',
              style: GoogleFonts.poppins(
                color: AppColors.title,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: _conteudo(context, controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context, HomeController controller) {
    if (controller.erro != null) {
      return [
        const SizedBox(height: 40),
        Text(
          controller.erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gray, fontSize: 13),
        ),
        Center(
          child: TextButton(
            onPressed: controller.carregar,
            child: const Text('Tentar de novo'),
          ),
        ),
      ];
    }
    // Só mostra o carregando na primeira vez; depois atualiza por cima.
    if (controller.carregando && controller.semDoses) {
      return const [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
      ];
    }

    final dose = controller.proximaDose;
    return [
      CardProximaDose(
        dose: dose,
        agora: controller.agora,
        semDoses: controller.semDoses,
        registrando: controller.registrando != null,
        onRegistrar: ({required tomada}) =>
            _registrar(context, controller, dose!, tomada: tomada),
      ),
      const SizedBox(height: 14),
      CardAdesao(tomadas: controller.tomadasHoje, total: controller.totalHoje),
      if (!controller.semDoses) ...[
        const SizedBox(height: 14),
        CardDosesDoDia(
          doses: controller.doses,
          agora: controller.agora,
          registrando: controller.registrando != null,
          onRegistrar: (dose, {required tomada}) =>
              _registrar(context, controller, dose, tomada: tomada),
        ),
      ],
      const SizedBox(height: 14),
      CardMia(onConhecer: () => _emBreve(context)),
    ];
  }

  Future<void> _registrar(
    BuildContext context,
    HomeController controller,
    Dose dose, {
    required bool tomada,
  }) async {
    try {
      await controller.registrar(dose, tomada: tomada);
      if (context.mounted) {
        AppSnackBar.info(
          context,
          tomada ? 'Dose registrada como tomada.' : 'Dose registrada como não tomada.',
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    }
  }
}
