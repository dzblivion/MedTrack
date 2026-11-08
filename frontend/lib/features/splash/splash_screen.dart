import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/rotas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                Text(
                  'Acompanhe seu tratamento de\nforma simples e organizada.',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    color: AppColors.darkCiano,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  texto: 'Começar',
                  onPressed: () => context.go(Rotas.cadastro),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Já tem uma conta? ',
                      style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10),
                    ),
                    InkWell(
                      onTap: () => context.go(Rotas.login),
                      child: Text(
                        'Entrar',
                        style: GoogleFonts.poppins(
                          color: AppColors.gray,
                          fontSize: 10,
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
