import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

/// Código de 6 dígitos mostrado em casinhas separadas, cada uma com um
/// traço embaixo.
///
/// Por trás das casinhas há um único campo de texto invisível: é ele que
/// recebe o que é digitado. Assim o teclado é só numérico, colar o código
/// inteiro preenche tudo de uma vez, o apagar volta casinha por casinha e
/// o celular consegue sugerir o código que chegou por e-mail.
class CampoCodigo extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final int tamanho;

  const CampoCodigo({
    super.key,
    required this.controller,
    this.validator,
    this.onSubmitted,
    this.tamanho = 6,
  });

  @override
  State<CampoCodigo> createState() => _CampoCodigoState();
}

class _CampoCodigoState extends State<CampoCodigo> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    // Redesenha as casinhas ao digitar, apagar, limpar (reenviar) e focar.
    widget.controller.addListener(_redesenhar);
    _foco.addListener(_redesenhar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redesenhar);
    _foco.dispose();
    super.dispose();
  }

  void _redesenhar() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final texto = widget.controller.text;
    // A casinha da vez: a próxima a ser preenchida (ou a última, se cheio).
    final atual = texto.length.clamp(0, widget.tamanho - 1);

    return FormField<String>(
      // Valida o texto do controller (ele pode ser limpo por fora).
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (campo) => Column(
        children: [
          Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.tamanho; i++)
                    _Casinha(
                      digito: i < texto.length ? texto[i] : null,
                      ativa: _foco.hasFocus && i == atual,
                      erro: campo.hasError,
                    ),
                ],
              ),
              // O campo de verdade, transparente, por cima das casinhas:
              // tocar em qualquer uma abre o teclado numérico.
              Positioned.fill(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _foco,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.tamanho),
                  ],
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration.collapsed(hintText: ''),
                  onChanged: (valor) {
                    campo.didChange(valor);
                    if (campo.hasError) campo.validate();
                  },
                  onSubmitted: widget.onSubmitted,
                ),
              ),
            ],
          ),
          if (campo.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                campo.errorText!,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.error,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dica embaixo do código: onde procurar o e-mail e quanto tempo ele vale.
class AjudaCodigo extends StatelessWidget {
  const AjudaCodigo({super.key});

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontFamily: 'Poppins',
      color: AppColors.gray,
      fontSize: 10,
    );
    return const SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: estilo,
          children: [
            TextSpan(text: 'Não encontrou? Confira o spam e a aba '),
            TextSpan(
              text: 'Promoções',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            TextSpan(text: ' do seu e-mail.\nO código vale por 10 minutos.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Casinha extends StatelessWidget {
  /// Nulo enquanto vazia (mostra um "0" clarinho de exemplo).
  final String? digito;
  final bool ativa;
  final bool erro;

  const _Casinha({required this.digito, required this.ativa, required this.erro});

  @override
  Widget build(BuildContext context) {
    final corTraco = erro
        ? AppColors.error
        : ativa
            ? AppColors.ciano
            : AppColors.field;

    return SizedBox(
      width: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            digito ?? '0',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: digito == null ? AppColors.field : AppColors.inputText,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: ativa ? 3 : 2,
            decoration: BoxDecoration(
              color: corTraco,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
