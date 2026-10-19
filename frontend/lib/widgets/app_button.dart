import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;

  const AppButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 40,
        child: FilledButton(
          onPressed: carregando ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ciano,
            disabledBackgroundColor: AppColors.ciano,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: carregando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
