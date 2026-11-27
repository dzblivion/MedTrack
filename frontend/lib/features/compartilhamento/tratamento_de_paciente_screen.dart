import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../../theme/app_theme.dart';
import '../doses/dose.dart';
import '../doses/resumo_doses.dart';
import '../historico/widgets/grupo_dia.dart';
import '../tratamentos/widgets/card_doses_tratamento.dart';
import '../tratamentos/widgets/informacoes_tratamento.dart';
import 'compartilhamento.dart';
import 'compartilhamento_repository.dart';

/// O profissional acompanhando um tratamento compartilhado: só leitura.
class TratamentoDePacienteScreen extends StatefulWidget {
  final int compartilhamentoId;

  const TratamentoDePacienteScreen({
    super.key,
    required this.compartilhamentoId,
  });

  @override
  State<TratamentoDePacienteScreen> createState() =>
      _TratamentoDePacienteScreenState();
}

class _TratamentoDePacienteScreenState
    extends State<TratamentoDePacienteScreen> {
  DetalheCompartilhado? _detalhe;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final detalhe = await context.read<CompartilhamentoRepository>().buscar(
        widget.compartilhamentoId,
      );
      if (mounted) setState(() => _detalhe = detalhe);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        title: const Text(
          'Tratamento do paciente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _carregar, child: _conteudo()),
      ),
    );
  }

  Widget _conteudo() {
    final detalhe = _detalhe;
    if (_erro != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Text(
            _erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray),
          ),
          Center(
            child: TextButton(
              onPressed: _carregar,
              child: const Text('Tentar de novo'),
            ),
          ),
        ],
      );
    }
    if (detalhe == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final t = detalhe.tratamento;
    final agora = DateTime.now();
    final dias = _diasAteHoje(detalhe.doses, agora);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color: AppColors.gray,
              size: 18,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                detalhe.pacienteNome,
                style: const TextStyle(color: AppColors.gray, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t.medicamento,
          style: const TextStyle(
            color: AppColors.darkCiano,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.status.rotulo,
          style: const TextStyle(color: AppColors.gray, fontSize: 13),
        ),
        const SizedBox(height: 20),
        InformacoesTratamento(tratamento: t),
        const SizedBox(height: 16),
        CardDosesTratamento(
          resumo: ResumoDoses.de(detalhe.doses, agora),
          usoContinuo: t.usoContinuo,
          falhou: false,
          onTentarDeNovo: _carregar,
        ),
        const SizedBox(height: 24),
        const Text(
          'Registro de doses',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.title,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (dias.isEmpty)
          const Text(
            'Nenhuma dose chegou no horário ainda.',
            style: TextStyle(color: AppColors.gray, fontSize: 13),
          )
        else
          for (final (:dia, :doses) in dias) ...[
            GrupoDia(
              rotulo: rotuloDoDia(dia, agora),
              doses: doses,
              agora: agora,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// Só as doses cujo horário já chegou, agrupadas por dia, como no
  /// Histórico do paciente.
  static List<({DateTime dia, List<Dose> doses})> _diasAteHoje(
    List<Dose> doses,
    DateTime agora,
  ) {
    final porDia = <DateTime, List<Dose>>{};
    for (final dose in doses) {
      final quando = dose.agendadaPara;
      if (quando.isAfter(agora)) continue;
      porDia
          .putIfAbsent(
            DateTime(quando.year, quando.month, quando.day),
            () => [],
          )
          .add(dose);
    }
    // As doses já vêm da mais recente para a mais antiga, e os dias também.
    return [for (final e in porDia.entries) (dia: e.key, doses: e.value)];
  }
}
