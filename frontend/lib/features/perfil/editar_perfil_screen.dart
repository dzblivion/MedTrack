import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../auth/sessao_controller.dart';
import '../auth/widgets/olho_senha.dart';
import 'conta_repository.dart';

const _fonte = 'Poppins';

/// Perfil → Editar perfil: trocar o nome e, no fim, excluir a conta.
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(
    text: context.read<SessaoController>().usuario?.nome ?? '',
  );
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  static String? _validarNome(String? valor) {
    final nome = valor?.trim() ?? '';
    if (nome.isEmpty) return 'Informe seu nome.';
    if (nome.length > 120) return 'Use no máximo 120 caracteres.';
    return null;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final sessao = context.read<SessaoController>();
    final nome = _nome.text.trim();
    if (nome == sessao.usuario?.nome) {
      context.pop();
      return;
    }

    setState(() => _salvando = true);
    try {
      final salvo = await context.read<ContaRepository>().alterarNome(nome);
      if (!mounted) return;
      AppSnackBar.info(context, 'Nome atualizado.');
      // Volta antes de avisar a sessão: o aviso faz as rotas se
      // reavaliarem e atropelaria a volta.
      context.pop();
      await sessao.atualizarNome(salvo);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirConta() async {
    final sessao = context.read<SessaoController>();
    final excluiu = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExcluirContaDialog(
        repositorio: context.read<ContaRepository>(),
      ),
    );
    if (excluiu != true || !mounted) return;
    // O aviso fica por cima da tela de login, para onde o app volta.
    AppSnackBar.info(context, 'Sua conta foi excluída.');
    await sessao.sair();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<SessaoController>().usuario?.email ?? '';

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
          'Editar perfil',
          style: TextStyle(
            fontFamily: _fonte,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              AppTextField(
                label: 'Nome completo',
                hint: 'Seu nome',
                controller: _nome,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                validator: _validarNome,
                onFieldSubmitted: (_) => _salvar(),
              ),
              const SizedBox(height: 16),
              const Text(
                'E-mail',
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.inputText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.field.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontFamily: _fonte,
                    color: AppColors.gray,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'O e-mail é usado para entrar e não pode ser alterado.',
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.gray,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                texto: 'Salvar',
                carregando: _salvando,
                onPressed: _salvar,
              ),
              const SizedBox(height: 40),
              const Divider(color: AppColors.field),
              const SizedBox(height: 8),
              const Text(
                'Excluir conta',
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Apaga para sempre sua conta e todos os seus dados no '
                'MedTrack.',
                style: TextStyle(
                  fontFamily: _fonte,
                  color: AppColors.gray,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _salvando ? null : _excluirConta,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Excluir minha conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explica o que some e pede a senha. Fecha com `true` se excluiu.
class _ExcluirContaDialog extends StatefulWidget {
  final ContaRepository repositorio;

  const _ExcluirContaDialog({required this.repositorio});

  @override
  State<_ExcluirContaDialog> createState() => _ExcluirContaDialogState();
}

class _ExcluirContaDialogState extends State<_ExcluirContaDialog> {
  final _senha = TextEditingController();
  bool _mostrarSenha = false;
  bool _excluindo = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Digite sua senha para confirmar.');
      return;
    }
    setState(() {
      _excluindo = true;
      _erro = null;
    });
    try {
      await widget.repositorio.excluir(_senha.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Algo deu errado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const texto = TextStyle(
      fontFamily: _fonte,
      color: AppColors.inputText,
      fontSize: 12,
    );

    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.error,
        size: 40,
      ),
      title: const Text('Excluir sua conta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isso apaga para sempre:\n'
              '• seus tratamentos e o histórico de doses;\n'
              '• os compartilhamentos com profissionais;\n'
              '• sua foto e seus dados de cadastro.\n\n'
              'Não dá para desfazer.',
              style: texto,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _senha,
              obscureText: !_mostrarSenha,
              enabled: !_excluindo,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _confirmar(),
              style: texto,
              decoration: InputDecoration(
                labelText: 'Sua senha',
                errorText: _erro,
                errorMaxLines: 2,
                suffixIcon: OlhoSenha(
                  visivel: _mostrarSenha,
                  onPressed: () =>
                      setState(() => _mostrarSenha = !_mostrarSenha),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _excluindo ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _excluindo ? null : _confirmar,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: _excluindo
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Excluir conta'),
        ),
      ],
    );
  }
}
