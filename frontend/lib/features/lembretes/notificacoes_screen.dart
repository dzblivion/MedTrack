import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import 'lembretes_controller.dart';
import 'preferencias_lembretes.dart';

const _fonte = 'Poppins';

/// Perfil → Notificações: liga/desliga os lembretes e escolhe quando avisar.
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  bool _testando = false;

  Future<void> _testar(LembretesController controller) async {
    setState(() => _testando = true);
    try {
      final enviou = await controller.testar();
      if (!mounted) return;
      if (enviou) {
        AppSnackBar.info(context, 'Notificação de teste enviada.');
      } else {
        AppSnackBar.erro(
          context,
          'As notificações estão bloqueadas. Libere nas configurações.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Não foi possível mostrar a notificação.');
      }
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  static String _rotuloAntes(int minutos) =>
      minutos == 0 ? 'Não' : '$minutos min antes';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LembretesController>();
    final p = controller.preferencias;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notificações',
          style: TextStyle(
            fontFamily: _fonte,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (!controller.agendaNoAparelho)
              const _Aviso(
                icone: Icons.phone_android_rounded,
                texto:
                    'No navegador não dá para avisar na hora das doses: os '
                    'lembretes funcionam no app instalado no celular. Aqui '
                    'você pode testar como a notificação aparece.',
              )
            else if (controller.permitido == false)
              const _Aviso(
                icone: Icons.notifications_off_outlined,
                cor: AppColors.error,
                texto:
                    'As notificações do MedTrack estão bloqueadas no celular. '
                    'Libere em Configurações → Apps → MedTrack → '
                    'Notificações.',
              ),
            _Cartao(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.ciano,
                  title: const Text('Lembrete das doses', style: _titulo),
                  subtitle: const Text(
                    'Aviso no horário de cada dose, com os botões '
                    '"Tomei" e "Não tomei"',
                    style: _descricao,
                  ),
                  value: p.ativo,
                  onChanged: (v) => controller.alterar(p.copyWith(ativo: v)),
                ),
                const Divider(height: 1, color: AppColors.field),
                const SizedBox(height: 12),
                Text(
                  'Lembrar antes também',
                  style: _titulo.copyWith(
                    color: p.ativo ? null : AppColors.gray,
                  ),
                ),
                const Text(
                  'Um aviso extra antes do horário (o principal continua '
                  'na hora da dose)',
                  style: _descricao,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutos
                        in PreferenciasLembretes.opcoesMinutosAntes)
                      ChoiceChip(
                        label: Text(_rotuloAntes(minutos)),
                        selected: p.minutosAntes == minutos,
                        selectedColor: AppColors.cianoClaro,
                        labelStyle: const TextStyle(
                          fontFamily: _fonte,
                          fontSize: 12,
                        ),
                        onSelected: p.ativo
                            ? (_) => controller.alterar(
                                p.copyWith(minutosAntes: minutos),
                              )
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
            if (controller.agendaNoAparelho && p.ativo) ...[
              const SizedBox(height: 10),
              Text(
                controller.agendados == 0
                    ? 'Nenhuma dose pendente para lembrar agora.'
                    : '${controller.agendados} '
                          '${controller.agendados == 1 ? 'dose com lembrete' : 'doses com lembrete'}'
                          ' nos próximos dias.',
                style: _descricao,
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _testando ? null : () => _testar(controller),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Enviar notificação de teste'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkCiano,
                side: const BorderSide(color: AppColors.ciano),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _titulo = TextStyle(
    fontFamily: _fonte,
    color: AppColors.inputText,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const _descricao = TextStyle(
    fontFamily: _fonte,
    color: AppColors.gray,
    fontSize: 11,
  );
}

class _Cartao extends StatelessWidget {
  final List<Widget> children;

  const _Cartao({required this.children});

  @override
  Widget build(BuildContext context) {
    // Material (e não Container) para o toque dos interruptores aparecer.
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;

  const _Aviso({
    required this.icone,
    required this.texto,
    this.cor = AppColors.darkCiano,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontFamily: _fonte,
                color: AppColors.inputText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
