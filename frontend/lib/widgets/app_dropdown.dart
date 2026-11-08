import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class AppDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? valor;
  final List<String> opcoes;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  /// Texto exibido para cada opção, quando difere do valor enviado à API.
  final String Function(String)? rotulo;

  const AppDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
    this.validator,
    this.rotulo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.inputText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          menuMaxHeight: 180,
          initialValue: valor,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: Transform.translate(offset: const Offset(10, 0), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gray, size: 18)),
          style: GoogleFonts.poppins(color: AppColors.gray, fontSize: 10, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: AppColors.hintText,
              fontSize: 10,
            ),
            filled: true,
            fillColor: AppColors.field,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 3,
            ),
            errorStyle: GoogleFonts.poppins(color: AppColors.error, fontSize: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppColors.ciano),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          items: opcoes
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(rotulo?.call(o) ?? o),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
