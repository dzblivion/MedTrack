import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/rotas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../tratamentos/tratamento.dart';
import 'medicamento_lido.dart';

/// O que a MIA encontrou na receita. Cada remédio abre o formulário já
/// preenchido; depois de salvo, fica marcado como cadastrado.
class ResultadoMiaScreen extends StatefulWidget {
  final ResultadoMia resultado;

  const ResultadoMiaScreen({super.key, required this.resultado});

  @override
  State<ResultadoMiaScreen> createState() => _ResultadoMiaScreenState();
}

class _ResultadoMiaScreenState extends State<ResultadoMiaScreen> {
  static const _fonte = 'Poppins';

  /// Índices dos remédios já cadastrados.
  final _cadastrados = <int>{};

  Future<void> _revisar(int indice) async {
    final salvou = await context.push<bool>(
      Rotas.miaRevisar,
      extra: widget.resultado.medicamentos[indice],
    );
    if (salvou == true) setState(() => _cadastrados.add(indice));
  }

  @override
  Widget build(BuildContext context) {
    final medicamentos = widget.resultado.medicamentos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Leitura da MIA',
          style: TextStyle(
            fontFamily: _fonte,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: medicamentos.isEmpty
                    ? _nadaEncontrado()
                    : [
                        Text(
                          medicamentos.length == 1
                              ? 'A MIA encontrou 1 medicamento.'
                              : 'A MIA encontrou ${medicamentos.length} '
                                  'medicamentos.',
                          style: const TextStyle(
                            fontFamily: _fonte,
                            color: AppColors.title,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Toque em cada um para conferir e cadastrar. '
                          'A extração da MIA pode conter erros.',
                          style: TextStyle(
                            fontFamily: _fonte,
                            color: AppColors.gray,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < medicamentos.length; i++) ...[
                          _CartaoMedicamento(
                            lido: medicamentos[i],
                            cadastrado: _cadastrados.contains(i),
                            onTap: () => _revisar(i),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _TextoLido(texto: widget.resultado.textoExtraido),
                      ],
              ),
            ),
            if (medicamentos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AppButton(
                  texto: 'Concluir',
                  onPressed: () => context.go(Rotas.inicio),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nadaEncontrado() => [
        const SizedBox(height: 40),
        const Icon(Icons.search_off_rounded, color: AppColors.gray, size: 48),
        const SizedBox(height: 8),
        const Text(
          'A MIA não encontrou medicamentos nesta imagem.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _fonte,
            color: AppColors.inputText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          'Tente uma foto mais nítida, com a receita inteira na moldura.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _fonte, color: AppColors.gray, fontSize: 11),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.pushReplacement(Rotas.mia),
            child: const Text('Tirar outra foto'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.pushReplacement(Rotas.miaRevisar),
            child: const Text('Cadastrar manualmente'),
          ),
        ),
        _TextoLido(texto: widget.resultado.textoExtraido),
      ];
}

class _CartaoMedicamento extends StatelessWidget {
  final MedicamentoLido lido;
  final bool cadastrado;
  final VoidCallback onTap;

  const _CartaoMedicamento({
    required this.lido,
    required this.cadastrado,
    required this.onTap,
  });

  static const _fonte = 'Poppins';

  @override
  Widget build(BuildContext context) {
    final valor = lido.dosagemValor;
    final detalhes = [
      if (valor != null) formatarDosagem(valor, lido.dosagemUnidade),
      ?formasConsumo[lido.formaConsumo],
      ?lido.frequenciaTexto,
    ].join(' · ');
    final conferir = lido.rotulosDuvidosos.length;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: cadastrado ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.medication_outlined, color: AppColors.ciano),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lido.medicamento ?? 'Nome não identificado',
                      style: const TextStyle(
                        fontFamily: _fonte,
                        color: AppColors.darkCiano,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detalhes.isNotEmpty)
                      Text(
                        detalhes,
                        style: const TextStyle(
                          fontFamily: _fonte,
                          color: AppColors.gray,
                          fontSize: 11,
                        ),
                      ),
                    if (conferir > 0 && !cadastrado)
                      Text(
                        conferir == 1
                            ? '1 campo para conferir'
                            : '$conferir campos para conferir',
                        style: const TextStyle(
                          fontFamily: _fonte,
                          color: Color(0xFF8A6100),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (cadastrado)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.ciano, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Cadastrado',
                      style: TextStyle(
                        fontFamily: _fonte,
                        color: AppColors.darkCiano,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Revisar ›',
                  style: TextStyle(
                    fontFamily: _fonte,
                    color: AppColors.ciano,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O texto que a leitura encontrou, escondido até a pessoa pedir.
class _TextoLido extends StatelessWidget {
  final String texto;

  const _TextoLido({required this.texto});

  @override
  Widget build(BuildContext context) {
    if (texto.trim().isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Ver o texto que a MIA leu',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.gray,
            fontSize: 11,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              texto,
              style: const TextStyle(color: AppColors.inputText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
