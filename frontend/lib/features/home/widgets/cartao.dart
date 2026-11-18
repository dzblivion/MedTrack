import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Card branco arredondado com sombra leve, usado nos blocos da Home.
class Cartao extends StatelessWidget {
  final Widget child;

  const Cartao({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

/// Título dos cards ("Próxima dose", "Adesão de hoje").
TextStyle get estiloTituloCartao => TextStyle(
      color: AppColors.darkCiano,
      fontFamily: 'Poppins',
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
