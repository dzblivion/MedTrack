import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../home/home_screen.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const LoginScreen({super.key, this.authRepository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();

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

    try {
      final usuario = await _auth.login(
        _emailController.text.trim(),
        _senhaController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(usuario: usuario)),
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

  void _emBreve() => AppSnackBar.info(context, 'Tela em construção.');

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Bem-vindo de volta!',
      subtitulo: 'Continue acompanhando seu cuidado.',
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
            _LinkTexto(texto: 'Esqueci minha senha', onTap: _emBreve),
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
                _LinkTexto(
                  texto: 'Criar Conta',
                  negrito: true,
                  onTap: _emBreve,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTexto extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  final bool negrito;

  const _LinkTexto({
    required this.texto,
    required this.onTap,
    this.negrito = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        texto,
        style: TextStyle(
          color: AppColors.gray,
          fontSize: 10,
          fontWeight: negrito ? FontWeight.w700 : FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
