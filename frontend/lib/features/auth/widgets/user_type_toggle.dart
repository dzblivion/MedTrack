import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      child: AnimatedScale(
        scale: ativo ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () => onChanged(tipo),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ativo ? AppColors.ciano : AppColors.cianoClaro,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
        
            ),
            child: Text(
              texto,
              style: GoogleFonts.poppins(
                color: ativo ? Colors.white : AppColors.darkCiano,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
