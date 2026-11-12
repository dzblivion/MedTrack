import '../../core/formatos.dart';
import '../tratamentos/tratamento.dart';

enum StatusDose {
  pendente('pendente'),
  tomada('tomada'),
  naoTomada('nao_tomada');

  final String api;

  const StatusDose(this.api);

  static StatusDose doBackend(String valor) => values.firstWhere(
        (status) => status.api == valor,
        orElse: () => StatusDose.pendente,
      );
}

/// Uma dose agendada pelo backend, já com o nome do remédio para exibir.
class Dose {
  final int id;
  final int tratamentoId;
  final String medicamento;

  /// "500 mg · 1 por dose".
  final String detalhe;

  /// Horário de Fortaleza/Brasília, sem fuso (como o backend devolve).
  final DateTime agendadaPara;
  final StatusDose status;

  const Dose({
    required this.id,
    required this.tratamentoId,
    required this.medicamento,
    required this.detalhe,
    required this.agendadaPara,
    required this.status,
  });

  /// Item de `GET /tratamentos/{id}/doses`; o remédio vem de [tratamento].
  factory Dose.fromJson(Map<String, dynamic> json, Tratamento tratamento) =>
      Dose(
        id: json['id'] as int,
        tratamentoId: tratamento.id,
        medicamento: tratamento.medicamento,
        detalhe: [
          ?tratamento.dosagem,
          '${formatarNumero(tratamento.quantidadePorDose)} por dose',
        ].join(' · '),
        agendadaPara: DateTime.parse(json['agendada_para'] as String),
        status: StatusDose.doBackend(json['status'] as String),
      );

  bool get pendente => status == StatusDose.pendente;

  /// O backend só aceita registrar a partir do horário agendado.
  bool podeRegistrar(DateTime agora) =>
      pendente && !agora.isBefore(agendadaPara);

  /// Quanto tempo depois do horário a dose passa a contar como atrasada.
  static const toleranciaAtraso = Duration(minutes: 1);

  /// Pendente e com o horário passado há pelo menos [toleranciaAtraso].
  bool atrasada(DateTime agora) =>
      pendente && !agora.isBefore(agendadaPara.add(toleranciaAtraso));

  /// "08:00".
  String get horario =>
      '${agendadaPara.hour.toString().padLeft(2, '0')}:'
      '${agendadaPara.minute.toString().padLeft(2, '0')}';
}
