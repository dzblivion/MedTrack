import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_field.dart';
import '../auth_repository.dart';
import '../auth_validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_link.dart';
import 'verificar_codigo_screen.dart';

class SolicitarCodigoScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final String emailInicial;

  const SolicitarCodigoScreen({
    super.key,
    this.authRepository,
    this.emailInicial = '',
  });

  @override
  State<SolicitarCodigoScreen> createState() => _SolicitarCodigoScreenState();
}

class _SolicitarCodigoScreenState extends State<SolicitarCodigoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.emailInicial,
  );
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();

  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);
    final email = _emailController.text.trim();

    try {
      await _auth.solicitarCodigo(email);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              VerificarCodigoScreen(email: email, authRepository: _auth),
        ),
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

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Esqueceu sua senha?',
      subtitulo: 'Enviaremos um código para o seu e-mail.',
      alturaCabecalho: 0.3,
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              onFieldSubmitted: (_) => _enviarCodigo(),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            AppButton(
              texto: 'Enviar código',
              carregando: _carregando,
              onPressed: _enviarCodigo,
            ),
            const SizedBox(height: 12),
            Center(
              child: AuthLink(
                texto: 'Voltar para o login',
                negrito: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
