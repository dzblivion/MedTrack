import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSnackBar {
  static void erro(BuildContext context, String mensagem) =>
      _mostrar(context, mensagem, AppColors.error);

  static void info(BuildContext context, String mensagem) =>
      _mostrar(context, mensagem, null);

  static void _mostrar(BuildContext context, String mensagem, Color? cor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }
}
