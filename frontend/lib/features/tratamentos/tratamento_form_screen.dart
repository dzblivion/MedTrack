import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import 'form/cabecalho_etapa.dart';
import 'form/etapa_duracao.dart';
import 'form/etapa_frequencia.dart';
import 'form/etapa_medicamento.dart';
import 'form/rascunho_tratamento.dart';
import 'tratamento.dart';
import 'tratamento_repository.dart';

/// Cadastra um tratamento novo ou edita [original], em 3 etapas.
/// Ao salvar, volta com `true`.
class TratamentoFormScreen extends StatefulWidget {
  final Tratamento? original;

  const TratamentoFormScreen({super.key, this.original});

  @override
  State<TratamentoFormScreen> createState() => _TratamentoFormScreenState();
}

class _TratamentoFormScreenState extends State<TratamentoFormScreen> {
  static const _totalEtapas = 3;

  final _formKey = GlobalKey<FormState>();
  late final _rascunho = RascunhoTratamento(widget.original);
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
      } else {
        await repositorio.criar(dados);
      }
      if (!mounted) return;

      AppSnackBar.info(
        context,
        _editando ? 'Tratamento atualizado!' : 'Tratamento cadastrado!',
      );
      context.pop(true);
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

  @override
  Widget build(BuildContext context) {
    final (icone, titulo, subtitulo, conteudo) = switch (_etapa) {
      0 => (
          Icons.medication_outlined,
          _editando ? 'Editar tratamento' : 'Novo tratamento',
          _editando
              ? 'Atualize as informações do tratamento.'
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
                  child: Form(key: _formKey, child: conteudo),
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
                      style: GoogleFonts.poppins(
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
