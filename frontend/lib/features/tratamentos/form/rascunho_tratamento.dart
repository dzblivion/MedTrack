import 'package:flutter/widgets.dart';

import '../../../core/formatos.dart';
import '../dados_tratamento.dart';
import '../frequencia.dart';
import '../tratamento.dart';

/// Opções do campo "Frequência" (etapa 2). "Em intervalos" vira
/// intervalo_horas ou intervalo_dias conforme a unidade escolhida.
enum ModoFrequencia {
  diario('Todos os dias'),
  semanal('Dias da semana'),
  intervalo('Em intervalos');

  final String rotulo;

  const ModoFrequencia(this.rotulo);
}

/// Tudo o que foi preenchido nas 3 etapas. Fica na tela do formulário, então
/// avançar e voltar entre as etapas não perde nada.
class RascunhoTratamento {
  final Tratamento? original;

  RascunhoTratamento(this.original);

  Frequencia? get _freq => original?.frequencia;

  // Etapa 1: medicamento.
  late final medicamento = TextEditingController(text: original?.medicamento);
  late final dosagem = TextEditingController(
    text: _numero(original?.dosagemValor),
  );
  late final quantidade = TextEditingController(
    text: _numero(original?.quantidadePorDose),
  );
  late String? unidade = original?.dosagemUnidade;
  late String? forma = original?.formaConsumo;

  // Etapa 2: frequência e horários.
  late ModoFrequencia? modo = switch (_freq?.tipo) {
    null => null,
    TipoFrequencia.diario => ModoFrequencia.diario,
    TipoFrequencia.semanal => ModoFrequencia.semanal,
    _ => ModoFrequencia.intervalo,
  };
  late bool intervaloEmDias = _freq?.tipo == TipoFrequencia.intervaloDias;
  late final intervalo = TextEditingController(
    text: _freq?.intervaloValor?.toString(),
  );

  /// "HH:MM", em ordem. Em intervalos, guarda só a primeira dose.
  late final List<String> horarios = [...?_freq?.horarios];
  late final Set<int> dias = {...?_freq?.diasSemana};
  late DateTime dataInicio = original?.dataInicio ?? _hoje();
  late final dataInicioTexto = TextEditingController(
    text: formatarData(dataInicio),
  );

  // Etapa 3: duração.
  late bool continuo = original?.usoContinuo ?? false;
  late final duracao = TextEditingController(
    text: original?.duracaoDias?.toString(),
  );
  late final termino = TextEditingController(text: _textoTermino());

  void mudarModo(ModoFrequencia novo) {
    modo = novo;
    // Em intervalos só existe o horário da primeira dose.
    if (novo == ModoFrequencia.intervalo && horarios.length > 1) {
      horarios.removeRange(1, horarios.length);
    }
  }

  void mudarDataInicio(DateTime data) {
    dataInicio = data;
    dataInicioTexto.text = formatarData(data);
    atualizarTermino();
  }

  /// Último dia, a partir da duração digitada; nulo no uso contínuo.
  DateTime? get dataTermino {
    final dias = int.tryParse(duracao.text.trim());
    if (continuo || dias == null || dias < 1) return null;
    return DateTime(dataInicio.year, dataInicio.month, dataInicio.day + dias - 1);
  }

  void atualizarTermino() => termino.text = _textoTermino();

  /// Escolher a data de término calcula a duração em dias.
  void mudarTermino(DateTime fim) {
    final inicio = DateTime.utc(
      dataInicio.year,
      dataInicio.month,
      dataInicio.day,
    );
    final dias =
        DateTime.utc(fim.year, fim.month, fim.day).difference(inicio).inDays + 1;
    duracao.text = '$dias';
    atualizarTermino();
  }

  Frequencia get frequencia => Frequencia(
        tipo: switch (modo!) {
          ModoFrequencia.diario => TipoFrequencia.diario,
          ModoFrequencia.semanal => TipoFrequencia.semanal,
          ModoFrequencia.intervalo => intervaloEmDias
              ? TipoFrequencia.intervaloDias
              : TipoFrequencia.intervaloHoras,
        },
        horarios: [...horarios]..sort(),
        diasSemana: [...dias]..sort(),
        intervaloValor: modo == ModoFrequencia.intervalo
            ? int.tryParse(intervalo.text.trim())
            : null,
      );

  /// Só chamar depois de validar as 3 etapas.
  DadosTratamento get dados => DadosTratamento(
        medicamento: medicamento.text.trim(),
        dosagemValor: lerNumero(dosagem.text),
        dosagemUnidade: unidade,
        quantidadePorDose: lerNumero(quantidade.text)!,
        formaConsumo: forma!,
        dataInicio: dataInicio,
        duracaoDias: continuo ? null : int.tryParse(duracao.text.trim()),
        frequencia: frequencia,
      );

  /// Linhas do "Resumo do tratamento" (etapa 3).
  List<(String, String)> get resumo {
    final valor = lerNumero(dosagem.text);
    final porDose = '${formatarNumero(lerNumero(quantidade.text) ?? 0)} por dose';
    final fim = dataTermino;
    return [
      ('Medicamento', medicamento.text.trim()),
      (
        'Dosagem',
        valor == null ? porDose : '${formatarDosagem(valor, unidade)} · $porDose',
      ),
      ('Forma de consumo', formasConsumo[forma] ?? ''),
      ('Frequência', frequencia.descricao),
      ('Início', formatarData(dataInicio)),
      if (!continuo) ('Término', fim == null ? '-' : formatarData(fim)),
    ];
  }

  void dispose() {
    for (final controller in [
      medicamento,
      dosagem,
      quantidade,
      intervalo,
      dataInicioTexto,
      duracao,
      termino,
    ]) {
      controller.dispose();
    }
  }

  String _textoTermino() {
    final fim = dataTermino;
    return fim == null ? '' : formatarData(fim);
  }

  static String? _numero(double? valor) =>
      valor == null ? null : formatarNumero(valor);

  static DateTime _hoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }
}
