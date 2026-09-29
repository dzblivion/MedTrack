import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_field.dart';
import '../auth_repository.dart';
import '../auth_validators.dart';
import '../widgets/auth_layout.dart';

class NovaSenhaScreen extends StatefulWidget {
  final String email;
  final String codigo;
  final AuthRepository? authRepository;

  const NovaSenhaScreen({
    super.key,
    required this.email,
    required this.codigo,
    this.authRepository,
  });

  @override
  State<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends State<NovaSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();

  bool _carregando = false;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      await _auth.redefinirSenha(
        email: widget.email,
        codigo: widget.codigo,
        novaSenha: _senhaController.text,
      );
      if (!mounted) return;

      AppSnackBar.info(context, 'Senha redefinida! Entre com a nova senha.');
      Navigator.of(context).popUntil((rota) => rota.isFirst);
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
      titulo: 'Crie uma nova senha',
      subtitulo: 'Use pelo menos 8 caracteres.',
      alturaCabecalho: 0.3,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nova senha',
              hint: 'Digite a nova senha',
              controller: _senhaController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.novaSenha,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Confirmar nova senha',
              hint: 'Confirme a nova senha',
              controller: _confirmarController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: AuthValidators.confirmarSenha(
                () => _senhaController.text,
              ),
              onFieldSubmitted: (_) => _redefinir(),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            AppButton(
              texto: 'Redefinir senha',
              carregando: _carregando,
              onPressed: _redefinir,
            ),
          ],
        ),
      ),
    );
  }
}
