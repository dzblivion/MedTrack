import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'dados_cadastro.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_link.dart';
import 'widgets/campo_codigo.dart';

/// Segundo passo do cadastro: digitar o código que chegou no e-mail.
/// A conta só é criada aqui, com o código.
class ConfirmarCadastroScreen extends StatefulWidget {
  final DadosCadastro dados;

  const ConfirmarCadastroScreen({super.key, required this.dados});

  /// O backend só aceita pedir outro código depois desse tempo.
  static const esperaReenvio = 60;

  @override
  State<ConfirmarCadastroScreen> createState() =>
      _ConfirmarCadastroScreenState();
}

class _ConfirmarCadastroScreenState extends State<ConfirmarCadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();

  bool _carregando = false;
  int _segundosParaReenviar = ConfirmarCadastroScreen.esperaReenvio;
  Timer? _contagem;

  @override
  void initState() {
    super.initState();
    _iniciarContagem();
  }

  @override
  void dispose() {
    _contagem?.cancel();
    _codigoController.dispose();
    super.dispose();
  }

  void _iniciarContagem() {
    _contagem?.cancel();
    setState(() => _segundosParaReenviar = ConfirmarCadastroScreen.esperaReenvio);
    _contagem = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_segundosParaReenviar <= 1) timer.cancel();
      setState(() => _segundosParaReenviar--);
    });
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;

    await _executar(() async {
      await context
          .read<AuthRepository>()
          .cadastrar(widget.dados, _codigoController.text.trim());
      if (!mounted) return;

      AppSnackBar.info(context, 'Conta criada com sucesso! Faça login.');
      context.go(Rotas.login);
    });
  }

  Future<void> _reenviar() async {
    await _executar(() async {
      await context
          .read<AuthRepository>()
          .solicitarCodigoCadastro(widget.dados.email);
      if (!mounted) return;

      _codigoController.clear();
      _iniciarContagem();
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
    final podeReenviar = _segundosParaReenviar <= 0 && !_carregando;

    return AuthLayout(
      titulo: 'Confirme seu e-mail',
      subtitulo: 'Digite o código de 6 dígitos que enviamos.',
      alturaCabecalho: 0.3,
      // Volta ao cadastro com tudo preenchido (ex.: e-mail digitado errado).
      onVoltar: () => context.pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(color: AppColors.gray, fontSize: 11),
                children: [
                  const TextSpan(text: 'Enviamos um código para '),
                  TextSpan(
                    text: widget.dados.email,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CampoCodigo(
              controller: _codigoController,
              validator: AuthValidators.codigo,
              onSubmitted: (_) => _confirmar(),
            ),
            const SizedBox(height: 16),
            const AjudaCodigo(),
            const Spacer(),
            const SizedBox(height: 24),
            AppButton(
              texto: 'Confirmar e criar conta',
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
                if (_segundosParaReenviar > 0)
                  Text(
                    'Reenviar em ${_segundosParaReenviar}s',
                    style: const TextStyle(color: AppColors.gray, fontSize: 10),
                  )
                else
                  AuthLink(
                    texto: 'Reenviar código',
                    negrito: true,
                    onTap: podeReenviar ? _reenviar : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
