import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Olho que mostra/esconde a senha, no fim do campo.
///
/// Compacto de propósito: o IconButton padrão reserva 48px de área de toque
/// e deixava o campo de senha mais alto que os outros.
class OlhoSenha extends StatelessWidget {
  final bool visivel;
  final VoidCallback onPressed;

  const OlhoSenha({super.key, required this.visivel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visivel ? 'Esconder senha' : 'Mostrar senha',
      onPressed: onPressed,
      icon: Icon(
        visivel ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.gray,
        size: 14,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 24),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
