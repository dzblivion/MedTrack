import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import 'tratamento.dart';
import 'tratamento_repository.dart';
import 'widgets/acoes_tratamento.dart';

/// Ao sair, devolve `true` se algo mudou, para a lista recarregar.
class TratamentoDetalheScreen extends StatefulWidget {
  final int id;

  const TratamentoDetalheScreen({super.key, required this.id});

  @override
  State<TratamentoDetalheScreen> createState() =>
      _TratamentoDetalheScreenState();
}

class _TratamentoDetalheScreenState extends State<TratamentoDetalheScreen> {
  Tratamento? _tratamento;
  String? _erro;
  bool _ocupado = false;
  bool _mudou = false;

  TratamentoRepository get _repositorio => context.read<TratamentoRepository>();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final tratamento = await _repositorio.buscar(widget.id);
      if (mounted) setState(() => _tratamento = tratamento);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar.');
    }
  }

  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      _mudou = true;
      await _carregar();
      if (mounted) AppSnackBar.info(context, sucesso);
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar() async {
    final editou = await context.push<bool>(
      Rotas.editarTratamento(widget.id),
      extra: _tratamento,
    );
    if (editou == true) {
      _mudou = true;
      await _carregar();
    }
  }

  void _mudarStatus(StatusTratamento status) {
    final mensagem = switch (status) {
      StatusTratamento.pausado => 'Tratamento pausado.',
      StatusTratamento.concluido => 'Tratamento concluído.',
      _ => 'Tratamento retomado.',
    };
    _executar(() => _repositorio.alterarStatus(widget.id, status), mensagem);
  }

  Future<void> _cancelar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Cancelar tratamento?'),
        content: const Text(
          'Ele vai para Finalizados e não poderá mais ser editado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancelar tratamento'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await _executar(
        () => _repositorio.cancelar(widget.id),
        'Tratamento cancelado.',
      );
    }
  }

  void _voltar() => context.pop(_mudou);

  @override
  Widget build(BuildContext context) {
    // Também cobre o "voltar" do sistema, para a lista saber se algo mudou.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _voltar();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.darkCiano,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: _voltar,
          ),
          title: const Text(
            'Tratamento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(child: _conteudo()),
      ),
    );
  }

  Widget _conteudo() {
    final t = _tratamento;

    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, style: const TextStyle(color: AppColors.gray)),
            TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }
    if (t == null) return const Center(child: CircularProgressIndicator());

    final hoje = DateTime.now();
    final progresso = t.status.emAndamento && !t.periodoEncerrado(hoje)
        ? 'dia ${t.diaAtual(hoje)} de ${t.duracaoDias}'
        : '${t.duracaoDias} dias';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
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
        _Informacoes(
          itens: [
            ('Dosagem', t.dosagem),
            ('Quantidade por dose', formatarNumero(t.quantidadePorDose)),
            ('Forma de consumo', formasConsumo[t.formaConsumo] ?? t.formaConsumo),
            (
              'Período',
              '${formatarData(t.dataInicio)} a ${formatarData(t.dataFim)}',
            ),
            ('Duração', progresso),
          ],
        ),
        const SizedBox(height: 24),
        AcoesTratamento(
          status: t.status,
          ocupado: _ocupado,
          onEditar: _editar,
          onMudarStatus: _mudarStatus,
          onCancelar: _cancelar,
        ),
      ],
    );
  }
}

class _Informacoes extends StatelessWidget {
  final List<(String, String)> itens;

  const _Informacoes({required this.itens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          for (final (rotulo, valor) in itens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rotulo,
                      style: const TextStyle(color: AppColors.gray, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      valor,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
