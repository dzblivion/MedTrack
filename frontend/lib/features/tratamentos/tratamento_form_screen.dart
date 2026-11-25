import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../../core/mudancas.dart';
import '../doses/dose_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../mia/medicamento_lido.dart';
import 'form/aviso_mia.dart';
import 'form/cabecalho_etapa.dart';
import 'form/etapa_duracao.dart';
import 'form/etapa_frequencia.dart';
import 'form/etapa_medicamento.dart';
import 'form/rascunho_tratamento.dart';
import 'tratamento.dart';
import 'tratamento_repository.dart';

/// Cadastra um tratamento novo ou edita [original], em 3 etapas.
/// Com [sugestao], o cadastro novo vem preenchido pelo que a MIA leu da
/// receita, para a pessoa revisar. Ao salvar, volta com `true`.
class TratamentoFormScreen extends StatefulWidget {
  final Tratamento? original;
  final MedicamentoLido? sugestao;

  const TratamentoFormScreen({super.key, this.original, this.sugestao});

  @override
  State<TratamentoFormScreen> createState() => _TratamentoFormScreenState();
}

class _TratamentoFormScreenState extends State<TratamentoFormScreen> {
  static const _totalEtapas = 3;

  final _formKey = GlobalKey<FormState>();
  late final _rascunho = RascunhoTratamento(
    widget.original,
    sugestao: widget.sugestao,
  );
  int _etapa = 0;
  bool _salvando = false;

  bool get _editando => widget.original != null;
  bool get _ultimaEtapa => _etapa == _totalEtapas - 1;

  @override
  void dispose() {
    _rascunho.dispose();
    super.dispose();
  }

  void _atualizar() => setState(() {});

  void _voltar() {
    if (_etapa == 0) {
      context.pop();
    } else {
      setState(() => _etapa--);
    }
  }

  /// Valida só a etapa atual antes de seguir.
  void _avancar() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_ultimaEtapa) {
      _salvar();
    } else {
      setState(() => _etapa++);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final repositorio = context.read<TratamentoRepository>();
    final dados = _rascunho.dados;

    try {
      if (_editando) {
        await repositorio.atualizar(widget.original!.id, dados);
        if (!mounted) return;
        // Início, Tratamentos e Histórico recarregam sozinhos.
        context.read<Mudancas>().tratamentosMudaram();
        AppSnackBar.info(context, 'Tratamento atualizado!');
        context.pop(true);
        return;
      }

      final id = await repositorio.criar(dados);
      final primeiraDose = await _primeiraDose(id);
      if (!mounted) return;
      context.read<Mudancas>().tratamentosMudaram();
      setState(() => _salvando = false);
      await _confirmarCadastro(primeiraDose);
      if (!mounted) return;

      // Da MIA, volta para a lista dos remédios lidos (pode haver outros);
      // senão, vai para o Início.
      if (widget.sugestao != null) {
        context.pop(true);
      } else {
        context.go(Rotas.inicio);
      }
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// "Primeira dose: amanhã às 00:00. Ela aparece no Início a partir de
  /// amanhã." O backend não cria doses em horários que já passaram, então
  /// a primeira pode ser só outro dia; avisar evita a pessoa achar que o
  /// cadastro não apareceu no Início (que mostra só as doses de hoje).
  /// Nulo se não souber (o cadastro já deu certo de qualquer jeito).
  Future<String?> _primeiraDose(int? id) async {
    if (id == null) return null;
    try {
      final quando = await context.read<DoseRepository>().primeiraPendente(id);
      if (quando == null) return null;
      final agora = DateTime.now();
      final aviso = 'Primeira dose: ${descreverQuando(quando, agora)}.';
      if (mesmoDia(quando, agora)) return aviso;
      return '$aviso\nEla aparece no Início a partir de '
          '${descreverDia(quando, agora)}.';
    } catch (_) {
      return null;
    }
  }

  /// Janela de confirmação do cadastro, com a primeira dose.
  Future<void> _confirmarCadastro(String? primeiraDose) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (contexto) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.ciano,
            size: 48,
          ),
          title: const Text('Tratamento cadastrado!'),
          content: Text(
            primeiraDose ?? 'Ele já aparece na sua lista de tratamentos.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(contexto).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.ciano),
              child: Text(
                widget.sugestao != null ? 'Continuar' : 'Ir para o Início',
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (icone, titulo, subtitulo, conteudo) = switch (_etapa) {
      0 => (
          Icons.medication_outlined,
          _editando
              ? 'Editar tratamento'
              : widget.sugestao != null
                  ? 'Revisar tratamento'
                  : 'Novo tratamento',
          _editando
              ? 'Atualize as informações do tratamento.'
              : widget.sugestao != null
                  ? 'Confira o que a MIA leu da sua receita.'
                  : 'Vamos cadastrar seu tratamento.',
          EtapaMedicamento(rascunho: _rascunho, onMudou: _atualizar) as Widget,
        ),
      1 => (
          Icons.schedule,
          'Frequência e horários',
          'É crucial para o app gerar os lembretes corretamente.',
          EtapaFrequencia(rascunho: _rascunho, onMudou: _atualizar),
        ),
      _ => (
          Icons.fact_check_outlined,
          'Duração e revisão',
          'Confira as informações antes de salvar.',
          EtapaDuracao(rascunho: _rascunho, onMudou: _atualizar),
        ),
    };

    // O "voltar" do sistema também volta uma etapa, em vez de fechar tudo.
    return PopScope(
      canPop: _etapa == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu && _etapa > 0) setState(() => _etapa--);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: CabecalhoEtapa(
                  etapa: _etapa + 1,
                  total: _totalEtapas,
                  icone: icone,
                  titulo: titulo,
                  subtitulo: subtitulo,
                  onVoltar: _voltar,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // Cada etapa começa do topo.
                  key: ValueKey(_etapa),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (widget.sugestao case final lido?)
                          AvisoMia(lido: lido, etapa: _etapa),
                        conteudo,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  children: [
                    AppButton(
                      texto: !_ultimaEtapa
                          ? 'Continuar'
                          : _editando
                              ? 'Salvar alterações'
                              : 'Salvar tratamento',
                      carregando: _salvando,
                      onPressed: _avancar,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '*Campos obrigatórios',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        color: AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
