import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Lista de opções com o visual dos campos do app. O menu abre logo abaixo
/// do campo (o DropdownButton padrão abria por cima dele).
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
    final bordaArredondada = BorderRadius.circular(5);
    OutlineInputBorder borda([Color? cor]) => OutlineInputBorder(
          borderRadius: bordaArredondada,
          borderSide: cor == null ? BorderSide.none : BorderSide(color: cor),
        );

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
        DropdownMenuFormField<String>(
          initialSelection: valor,
          onSelected: onChanged,
          validator: validator,
          hintText: hint,
          // Ocupa a largura toda e não deixa digitar: só escolher.
          expandedInsets: EdgeInsets.zero,
          selectOnly: true,
          requestFocusOnTap: false,
          menuHeight: 180,
          alignmentOffset: const Offset(0, 4),
          textStyle: GoogleFonts.poppins(
            color: AppColors.inputText,
            fontSize: 10,
          ),
          // Seta simples (sem o botão redondo padrão), para o campo ter a
          // mesma altura dos campos de texto.
          decorationBuilder: (context, menu) => InputDecoration(
            suffixIcon: Icon(
              menu.isOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.gray,
              size: 18,
            ),
          ),
          inputDecorationTheme: InputDecorationThemeData(
            filled: true,
            fillColor: AppColors.field,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 8,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 0,
            ),
            hintStyle: GoogleFonts.poppins(
              color: AppColors.hintText,
              fontSize: 10,
            ),
            errorStyle: GoogleFonts.poppins(
              color: AppColors.error,
              fontSize: 10,
            ),
            border: borda(),
            enabledBorder: borda(),
            focusedBorder: borda(AppColors.ciano),
            errorBorder: borda(AppColors.error),
            focusedErrorBorder: borda(AppColors.error),
          ),
          menuStyle: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(4),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          dropdownMenuEntries: [
            for (final opcao in opcoes)
              DropdownMenuEntry(
                value: opcao,
                label: rotulo?.call(opcao) ?? opcao,
                style: MenuItemButton.styleFrom(
                  foregroundColor: AppColors.inputText,
                  textStyle: GoogleFonts.poppins(fontSize: 11),
                  minimumSize: const Size.fromHeight(36),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
