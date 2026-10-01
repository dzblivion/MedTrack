import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/app_text_field.dart';
import '../auth_repository.dart';
import '../auth_validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_link.dart';
import 'nova_senha_screen.dart';

class VerificarCodigoScreen extends StatefulWidget {
  final String email;
  final AuthRepository? authRepository;

  const VerificarCodigoScreen({
    super.key,
    required this.email,
    this.authRepository,
  });

  @override
  State<VerificarCodigoScreen> createState() => _VerificarCodigoScreenState();
}

class _VerificarCodigoScreenState extends State<VerificarCodigoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();

  bool _carregando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;

    final codigo = _codigoController.text.trim();

    await _executar(() async {
      await _auth.verificarCodigo(widget.email, codigo);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NovaSenhaScreen(
            email: widget.email,
            codigo: codigo,
            authRepository: _auth,
          ),
        ),
      );
    });
  }

  Future<void> _reenviar() async {
    await _executar(() async {
      await _auth.solicitarCodigo(widget.email);
      if (!mounted) return;

      _codigoController.clear();
      AppSnackBar.info(context, 'Enviamos um novo código para o seu e-mail.');
    });
  }

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _carregando = true);

    try {
      await acao();
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
      titulo: 'Verifique seu e-mail',
      subtitulo: 'Digite o código de 6 dígitos que enviamos.',
      alturaCabecalho: 0.3,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(color: AppColors.gray, fontSize: 11),
                children: [
                  const TextSpan(text: 'Se houver uma conta com '),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ', enviamos um código para ele.'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Código',
              hint: '000000',
              controller: _codigoController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: AuthValidators.codigo,
              onFieldSubmitted: (_) => _confirmar(),
            ),
            const SizedBox(height: 8),
            const Text(
              'O código vale por 10 minutos.',
              style: TextStyle(color: AppColors.gray, fontSize: 10),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            AppButton(
              texto: 'Confirmar código',
              carregando: _carregando,
              onPressed: _confirmar,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Não recebeu? ',
                  style: TextStyle(color: AppColors.gray, fontSize: 10),
                ),
                AuthLink(
                  texto: 'Reenviar código',
                  negrito: true,
                  onTap: _carregando ? null : _reenviar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
