import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../../core/mudancas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import 'compartilhamento.dart';
import 'compartilhamento_repository.dart';

/// Paciente: pedidos de acesso para aprovar, quem tem acesso e os códigos
/// ainda não usados.
class CompartilhamentosScreen extends StatefulWidget {
  const CompartilhamentosScreen({super.key});

  @override
  State<CompartilhamentosScreen> createState() =>
      _CompartilhamentosScreenState();
}

class _CompartilhamentosScreenState extends State<CompartilhamentosScreen> {
  static const _fonte = 'Poppins';

  List<PedidoDeAcesso> _pedidos = const [];
  List<CompartilhamentoDoPaciente> _todos = const [];
  bool _carregando = true;
  bool _ocupado = false;
  String? _erro;

  CompartilhamentoRepository get _repositorio =>
      context.read<CompartilhamentoRepository>();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final (pedidos, todos) = await (
        _repositorio.pedidosPendentes(),
        _repositorio.listarDoPaciente(),
      ).wait;
      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _todos = todos;
        });
      }
    } on ParallelWaitError catch (e) {
      final erro = (e.errors.$1 ?? e.errors.$2)?.error;
      if (mounted) {
        setState(
          () => _erro = erro is ApiException
              ? erro.mensagem
              : 'Não foi possível carregar os compartilhamentos.',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Faz a ação, avisa e recarrega (o aviso no Início também).
  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      if (!mounted) return;
      context.read<Mudancas>().tratamentosMudaram();
      AppSnackBar.info(context, sucesso);
      await _carregar();
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _decidir(PedidoDeAcesso pedido, {required bool aprovar}) => _executar(
    () => _repositorio.decidir(pedido.compartilhamentoId, aprovar: aprovar),
    aprovar
        ? '${pedido.profissional.nome} agora acompanha ${pedido.medicamento}.'
        : 'Pedido recusado.',
  );

  Future<void> _revogar(CompartilhamentoDoPaciente item) async {
    final quem = item.profissional?.nome;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(quem == null ? 'Invalidar o código?' : 'Tirar o acesso?'),
        content: Text(
          quem == null
              ? 'O código de ${item.medicamento} deixa de funcionar.'
              : '$quem deixa de ver ${item.medicamento}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(quem == null ? 'Invalidar' : 'Tirar acesso'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await _executar(
        () => _repositorio.revogar(item.id),
        quem == null ? 'Código invalidado.' : 'Acesso retirado.',
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Compartilhamentos',
          style: TextStyle(
            fontFamily: _fonte,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: _conteudo(),
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo() {
    if (_carregando && _todos.isEmpty && _pedidos.isEmpty) {
      return const [
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (_erro != null) {
      return [
        const SizedBox(height: 40),
        Text(_erro!, textAlign: TextAlign.center),
        Center(
          child: TextButton(
            onPressed: _carregar,
            child: const Text('Tentar de novo'),
          ),
        ),
      ];
    }

    final ativos = [
      for (final c in _todos)
        if (c.status == StatusCompartilhamento.ativo) c,
    ];
    final codigos = [
      for (final c in _todos)
        if (c.status == StatusCompartilhamento.pendente) c,
    ];
    final encerrados = [
      for (final c in _todos)
        if (c.status.encerrado) c,
    ];

    if (_pedidos.isEmpty && ativos.isEmpty && codigos.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Icon(Icons.share_outlined, color: AppColors.gray, size: 48),
        const SizedBox(height: 8),
        const Text(
          'Nenhum profissional acompanha seus tratamentos.\n\nPara '
          'compartilhar, abra um tratamento e toque em '
          '"Compartilhar com profissional".',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _fonte, color: AppColors.gray),
        ),
        if (encerrados.isNotEmpty) _Encerrados(itens: encerrados),
      ];
    }

    return [
      if (_pedidos.isNotEmpty) ...[
        _Secao('Pedidos de acesso (${_pedidos.length})'),
        for (final p in _pedidos)
          _Cartao(
            titulo: p.profissional.nome,
            subtitulo: p.profissional.descricao,
            detalhe: 'quer acompanhar: ${p.medicamento}',
            destaque: true,
            acoes: [
              TextButton(
                onPressed: _ocupado ? null : () => _decidir(p, aprovar: false),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Recusar'),
              ),
              FilledButton(
                onPressed: _ocupado ? null : () => _decidir(p, aprovar: true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.ciano),
                child: const Text('Aprovar'),
              ),
            ],
          ),
      ],
      if (ativos.isNotEmpty) ...[
        const _Secao('Com acesso'),
        for (final c in ativos)
          _Cartao(
            titulo: c.profissional?.nome ?? 'Profissional',
            subtitulo: c.profissional?.descricao ?? '',
            detalhe: 'acompanha: ${c.medicamento}',
            acoes: [
              TextButton(
                onPressed: _ocupado ? null : () => _revogar(c),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Tirar acesso'),
              ),
            ],
          ),
      ],
      if (codigos.isNotEmpty) ...[
        const _Secao('Códigos aguardando uso'),
        for (final c in codigos)
          _Cartao(
            titulo: c.medicamento,
            subtitulo: c.criadoEm == null
                ? 'Código gerado'
                : 'Código gerado em ${formatarData(c.criadoEm!)}',
            detalhe: 'Ainda nenhum profissional usou este código.',
            acoes: [
              TextButton(
                onPressed: _ocupado ? null : () => _revogar(c),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Invalidar'),
              ),
            ],
          ),
      ],
      if (encerrados.isNotEmpty) _Encerrados(itens: encerrados),
    ];
  }
}

class _Secao extends StatelessWidget {
  final String texto;

  const _Secao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.title,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String detalhe;
  final List<Widget> acoes;
  final bool destaque;

  const _Cartao({
    required this.titulo,
    required this.subtitulo,
    required this.detalhe,
    required this.acoes,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    const fonte = 'Poppins';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: destaque
            ? Border.all(color: AppColors.ciano, width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontFamily: fonte,
              color: AppColors.darkCiano,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitulo.isNotEmpty)
            Text(
              subtitulo,
              style: const TextStyle(
                fontFamily: fonte,
                color: AppColors.gray,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            detalhe,
            style: const TextStyle(
              fontFamily: fonte,
              color: AppColors.inputText,
              fontSize: 12,
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: acoes),
        ],
      ),
    );
  }
}

/// Recusados, revogados e expirados, escondidos até a pessoa abrir.
class _Encerrados extends StatelessWidget {
  final List<CompartilhamentoDoPaciente> itens;

  const _Encerrados({required this.itens});

  static String _rotulo(StatusCompartilhamento s) => switch (s) {
    StatusCompartilhamento.recusado => 'recusado',
    StatusCompartilhamento.revogado => 'acesso retirado',
    _ => 'expirado',
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Encerrados (${itens.length})',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.gray,
            fontSize: 13,
          ),
        ),
        children: [
          for (final c in itens)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.profissional?.nome ?? c.medicamento),
              subtitle: Text('${c.medicamento} · ${_rotulo(c.status)}'),
            ),
        ],
      ),
    );
  }
}
