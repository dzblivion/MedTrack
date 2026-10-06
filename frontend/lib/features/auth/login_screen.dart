import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import 'auth_validators.dart';
import 'sessao_controller.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_link.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    // Com a sessão ativa, as rotas levam sozinhas para o Início.
    try {
      await context.read<SessaoController>().entrar(
            _emailController.text.trim(),
            _senhaController.text,
          );
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _esqueciSenha() {
    context.push(Rotas.recuperarSenha, extra: _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Bem-vindo de volta!',
      subtitulo: 'Continue acompanhando seu cuidado.',
      marcaCabecalho: const AppLogo(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'E-mail',
              hint: 'seu@email.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Senha',
              hint: 'Digite sua senha',
              controller: _senhaController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: AuthValidators.senhaObrigatoria,
              onFieldSubmitted: (_) => _entrar(),
            ),
            const SizedBox(height: 20),
            AuthLink(texto: 'Esqueci minha senha', onTap: _esqueciSenha),
            const Spacer(),
            const SizedBox(height: 24),
            AppButton(
              texto: 'Entrar',
              carregando: _carregando,
              onPressed: _entrar,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Ainda não tem uma conta? ',
                  style: TextStyle(color: AppColors.gray, fontSize: 10),
                ),
                AuthLink(
                  texto: 'Criar Conta',
                  negrito: true,
                  onTap: () => context.push(Rotas.cadastro),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
