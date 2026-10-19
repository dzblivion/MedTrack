import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

enum TipoConta { usuario, profissional }

class UserTypeToggle extends StatelessWidget {
  final TipoConta selecionado;
  final ValueChanged<TipoConta> onChanged;

  const UserTypeToggle({
    super.key,
    required this.selecionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _opcao('Usuario', TipoConta.usuario),
        const SizedBox(width: 12),
        _opcao('Profissional', TipoConta.profissional),
      ],
    );
  }

  Widget _opcao(String texto, TipoConta tipo) {
    final ativo = tipo == selecionado;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tipo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativo ? AppColors.ciano : AppColors.cianoClaro,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: ativo ? Colors.white : AppColors.darkCiano,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
