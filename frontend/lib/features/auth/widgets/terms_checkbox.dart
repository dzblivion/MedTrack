import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TermsCheckbox extends StatelessWidget {
  final bool aceito;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTermos;
  final VoidCallback onTapPrivacidade;

  const TermsCheckbox({
    super.key,
    required this.aceito,
    required this.onChanged,
    required this.onTapTermos,
    required this.onTapPrivacidade,
  });

  static const _estiloTexto = TextStyle(
    color: AppColors.gray,
    fontSize: 10,
  );

  static const _estiloLink = TextStyle(
    color: AppColors.darkCiano,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: aceito,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.ciano,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                style: _estiloTexto,
                children: [
                  const TextSpan(text: 'Li e concordo com os '),
                  TextSpan(
                    text: 'Termos de Uso',
                    style: _estiloLink,
                    recognizer: TapGestureRecognizer()..onTap = onTapTermos,
                  ),
                  const TextSpan(text: ' e a '),
                  TextSpan(
                    text: 'Política de Privacidade',
                    style: _estiloLink,
                    recognizer: TapGestureRecognizer()
                      ..onTap = onTapPrivacidade,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
