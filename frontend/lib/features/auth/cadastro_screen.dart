import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import 'auth_repository.dart';
import 'auth_validators.dart';
import 'br_estados.dart';
import 'profissoes_saude.dart';
import 'widgets/auth_layout.dart';
import 'widgets/terms_checkbox.dart';
import 'widgets/user_type_toggle.dart';

class CadastroScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const CadastroScreen({super.key, this.authRepository});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _registroController = TextEditingController();
  late final AuthRepository _auth = widget.authRepository ?? AuthRepository();

  TipoConta _tipo = TipoConta.usuario;
  String? _profissao;
  String? _ufRegistro;
  bool _aceitaTermos = false;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _registroController.dispose();
    super.dispose();
  }

  bool get _ehProfissional => _tipo == TipoConta.profissional;

  Future<void> _criarConta() async {
    final formValido = _formKey.currentState!.validate();

    if (!_aceitaTermos) {
      AppSnackBar.erro(context, 'Você precisa aceitar os termos para continuar.');
    }

    if (!formValido || !_aceitaTermos) return;

    setState(() => _carregando = true);

    try {
      if (_ehProfissional) {
        await _auth.cadastrarProfissional(
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim(),
          senha: _senhaController.text,
          profissao: _profissao!,
          registro: _registroController.text.trim(),
          ufRegistro: _ufRegistro!,
        );
      } else {
        await _auth.cadastrarUsuario(
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim(),
          senha: _senhaController.text,
        );
      }

      if (!mounted) return;

      AppSnackBar.info(context, 'Conta criada com sucesso! Faça login.');
      Navigator.of(context).pop();
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
      titulo: 'Crie sua conta!',
      subtitulo: 'Seu cuidado começa aqui.',
      alturaCabecalho: 0.2,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quero me cadastrar como:',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            UserTypeToggle(
              selecionado: _tipo,
              onChanged: (tipo) => setState(() => _tipo = tipo),
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Nome completo',
              hint: 'Digite seu nome',
              controller: _nomeController,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.nome,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'E-mail',
              hint: 'seu@email.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            if (_ehProfissional) ...[
              const SizedBox(height: 14),
              AppDropdown(
                label: 'Profissão',
                hint: 'Selecione sua profissão',
                valor: _profissao,
                opcoes: profissoesSaude,
                onChanged: (v) => setState(() => _profissao = v),
                validator: (v) =>
                    AuthValidators.campoObrigatorio(v, 'sua profissão'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: 'Número do registro',
                      hint: 'Ex: CRM, COREN, CRF...',
                      controller: _registroController,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          AuthValidators.campoObrigatorio(v, 'o registro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppDropdown(
                      label: 'UF do registro',
                      hint: 'Estado',
                      valor: _ufRegistro,
                      opcoes: brEstados,
                      onChanged: (v) => setState(() => _ufRegistro = v),
                      validator: (v) =>
                          AuthValidators.campoObrigatorio(v, 'a UF'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              label: 'Senha',
              hint: 'Digite sua senha',
              controller: _senhaController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.novaSenha,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Confirmar senha',
              hint: 'Confirme sua senha',
              controller: _confirmarSenhaController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: AuthValidators.confirmarSenha(
                () => _senhaController.text,
              ),
              onFieldSubmitted: (_) => _criarConta(),
            ),
            const SizedBox(height: 8),
            TermsCheckbox(
              aceito: _aceitaTermos,
              onChanged: (v) => setState(() => _aceitaTermos = v),
              onTapLink: () =>
                  AppSnackBar.info(context, 'Tela em construção.'),
            ),
            const SizedBox(height: 16),
            AppButton(
              texto: 'Criar minha conta',
              carregando: _carregando,
              onPressed: _criarConta,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Já tem uma conta? ',
                  style: TextStyle(color: AppColors.gray, fontSize: 10),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      color: AppColors.gray,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
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
