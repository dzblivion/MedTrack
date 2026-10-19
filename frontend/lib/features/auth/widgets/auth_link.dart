import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class AuthLink extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final bool negrito;

  const AuthLink({
    super.key,
    required this.texto,
    required this.onTap,
    this.negrito = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        texto,
        style: TextStyle(
          color: AppColors.gray,
          fontSize: 10,
          fontWeight: negrito ? FontWeight.w700 : FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
