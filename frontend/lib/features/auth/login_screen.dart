import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import '../home/home_screen.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'cadastro_screen.dart';
import 'recuperar_senha/solicitar_codigo_screen.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_link.dart';

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

  void _esqueciSenha() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitarCodigoScreen(
          authRepository: _auth,
          emailInicial: _emailController.text.trim(),
        ),
      ),
    );
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CadastroScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
