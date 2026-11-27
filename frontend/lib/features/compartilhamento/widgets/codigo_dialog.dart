import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

/// Mostra o código gerado para o profissional. O backend só devolve o
/// código uma vez, então a janela deixa copiar e avisa disso.
Future<void> mostrarCodigoCompartilhamento(
  BuildContext context, {
  required String codigo,
  required String medicamento,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CodigoDialog(codigo: codigo, medicamento: medicamento),
);

class _CodigoDialog extends StatefulWidget {
  final String codigo;
  final String medicamento;

  const _CodigoDialog({required this.codigo, required this.medicamento});

  @override
  State<_CodigoDialog> createState() => _CodigoDialogState();
}

class _CodigoDialogState extends State<_CodigoDialog> {
  static const _fonte = 'Poppins';
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.codigo));
    if (mounted) setState(() => _copiado = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.share_outlined, color: AppColors.ciano, size: 40),
      title: const Text('Código de compartilhamento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Para: ${widget.medicamento}',
            style: const TextStyle(fontFamily: _fonte, color: AppColors.gray),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cianoClaro,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              widget.codigo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppColors.inputText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _copiar,
              icon: Icon(_copiado ? Icons.check : Icons.copy, size: 18),
              label: Text(_copiado ? 'Código copiado!' : 'Copiar código'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.ciano),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Envie ao profissional. Ele cola o código no app e você aprova o '
            'acesso em Perfil → Compartilhamentos.\n\n'
            'Atenção: o código aparece só agora. Se perder, gere outro.',
            style: TextStyle(
              fontFamily: _fonte,
              color: AppColors.gray,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
