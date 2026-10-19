import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/formatos.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import 'dados_tratamento.dart';
import 'tratamento.dart';
import 'tratamento_repository.dart';
import 'tratamento_validators.dart';

/// Cadastra um tratamento novo ou edita [original]. Ao salvar, volta com `true`.
class TratamentoFormScreen extends StatefulWidget {
  final Tratamento? original;

  const TratamentoFormScreen({super.key, this.original});

  @override
  State<TratamentoFormScreen> createState() => _TratamentoFormScreenState();
}

class _TratamentoFormScreenState extends State<TratamentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final DadosTratamento? _inicial = widget.original == null
      ? null
      : DadosTratamento.de(widget.original!);

  late final _medicamento = TextEditingController(text: _inicial?.medicamento);
  late final _dosagem = TextEditingController(
    text: _numeroInicial(_inicial?.dosagemValor),
  );
  late final _quantidade = TextEditingController(
    text: _numeroInicial(_inicial?.quantidadePorDose) ?? '1',
  );
  late final _duracao = TextEditingController(
    text: _inicial?.duracaoDias.toString(),
  );
  late final _dataTexto = TextEditingController(text: formatarData(_dataInicio));

  late String _unidade = _inicial?.dosagemUnidade ?? 'mg';
  late String _forma = _inicial?.formaConsumo ?? 'oral';
  late DateTime _dataInicio = _inicial?.dataInicio ?? _hoje();
  bool _salvando = false;

  bool get _editando => widget.original != null;

  static String? _numeroInicial(double? valor) =>
      valor == null ? null : formatarNumero(valor);

  static DateTime _hoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  @override
  void dispose() {
    _medicamento.dispose();
    _dosagem.dispose();
    _quantidade.dispose();
    _duracao.dispose();
    _dataTexto.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data de início',
    );
    if (escolhida == null) return;

    setState(() {
      _dataInicio = escolhida;
      _dataTexto.text = formatarData(escolhida);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dados = DadosTratamento(
      medicamento: _medicamento.text.trim(),
      dosagemValor: lerNumero(_dosagem.text)!,
      dosagemUnidade: _unidade,
      quantidadePorDose: lerNumero(_quantidade.text)!,
      formaConsumo: _forma,
      dataInicio: _dataInicio,
      duracaoDias: int.parse(_duracao.text.trim()),
    );

    setState(() => _salvando = true);
    final repositorio = context.read<TratamentoRepository>();

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
        title: Text(
          _editando ? 'Editar tratamento' : 'Novo tratamento',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Medicamento',
                  hint: 'Ex.: Amoxicilina',
                  controller: _medicamento,
                  textInputAction: TextInputAction.next,
                  validator: TratamentoValidators.medicamento,
                ),
                const SizedBox(height: 14),
                _linha(
                  AppTextField(
                    label: 'Dosagem',
                    hint: 'Ex.: 500',
                    controller: _dosagem,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: TratamentoValidators.numeroPositivo('a dosagem'),
                  ),
                  AppDropdown(
                    label: 'Unidade',
                    hint: 'Unidade',
                    valor: _unidade,
                    opcoes: unidadesDosagem.keys.toList(),
                    rotulo: (valor) => unidadesDosagem[valor]!,
                    onChanged: (v) => setState(() => _unidade = v ?? _unidade),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Quantidade por dose',
                  hint: 'Ex.: 1 (comprimido, cápsula...)',
                  controller: _quantidade,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: TratamentoValidators.numeroPositivo(
                    'a quantidade',
                  ),
                ),
                const SizedBox(height: 14),
                AppDropdown(
                  label: 'Forma de consumo',
                  hint: 'Selecione',
                  valor: _forma,
                  opcoes: formasConsumo.keys.toList(),
                  rotulo: (valor) => formasConsumo[valor]!,
                  onChanged: (v) => setState(() => _forma = v ?? _forma),
                ),
                const SizedBox(height: 14),
                _linha(
                  AppTextField(
                    label: 'Data de início',
                    hint: 'dd/mm/aaaa',
                    controller: _dataTexto,
                    onTap: _escolherData,
                  ),
                  AppTextField(
                    label: 'Duração (dias)',
                    hint: 'Ex.: 7',
                    controller: _duracao,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: TratamentoValidators.duracao,
                  ),
                ),
                const SizedBox(height: 28),
                AppButton(
                  texto: _editando ? 'Salvar alterações' : 'Salvar tratamento',
                  carregando: _salvando,
                  onPressed: _salvar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linha(Widget esquerda, Widget direita) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: esquerda),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: direita),
        ],
      );
}
