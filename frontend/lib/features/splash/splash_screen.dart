import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';
import '../auth/cadastro_screen.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  void _irPara(BuildContext context, Widget tela) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.ciano, AppColors.background],
            stops: [0.0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const AppLogo(claro: true),
                const Spacer(flex: 4),
                const Text(
                  'Acompanhe seu tratamento de\nforma simples e organizada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkCiano,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  texto: 'Começar',
                  onPressed: () => _irPara(context, const CadastroScreen()),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta? ',
                      style: TextStyle(color: AppColors.gray, fontSize: 12),
                    ),
                    InkWell(
                      onTap: () => _irPara(context, const LoginScreen()),
                      child: const Text(
                        'Entrar',
                        style: TextStyle(
                          color: AppColors.gray,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
