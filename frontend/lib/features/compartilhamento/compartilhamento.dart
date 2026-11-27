import '../doses/dose.dart';
import '../tratamentos/tratamento.dart';

/// Situação de um compartilhamento no backend.
enum StatusCompartilhamento {
  /// Código gerado, ainda não usado por um profissional.
  pendente('pendente'),

  /// Um profissional usou o código; falta o paciente aprovar.
  aguardandoAprovacao('aguardando_aprovacao'),
  ativo('ativo'),
  recusado('recusado'),
  revogado('revogado'),
  expirado('expirado');

  final String api;

  const StatusCompartilhamento(this.api);

  static StatusCompartilhamento doBackend(String? valor) => values.firstWhere(
    (s) => s.api == valor,
    orElse: () => StatusCompartilhamento.expirado,
  );

  bool get encerrado =>
      this == recusado || this == revogado || this == expirado;
}

/// Quem pediu ou tem acesso: "Dra. Ana · Médico(a) · CRM 12345/PB".
class ProfissionalResumo {
  final String nome;
  final String? profissao;
  final String? registro;
  final String? uf;

  const ProfissionalResumo({
    required this.nome,
    this.profissao,
    this.registro,
    this.uf,
  });

  /// Nulo quando o código ainda não foi usado por ninguém.
  static ProfissionalResumo? doJson(Map<String, dynamic> json) {
    final nome = json['profissional_nome'] as String?;
    if (nome == null) return null;
    return ProfissionalResumo(
      nome: nome,
      profissao: json['profissao'] as String?,
      registro: json['registro'] as String?,
      uf: json['uf_registro'] as String?,
    );
  }

  /// "Médico(a) · CRM 12345/PB".
  String get descricao => [
    ?profissao,
    if (registro != null) uf == null ? registro! : '$registro/$uf',
  ].join(' · ');
}

/// Um compartilhamento visto pelo paciente (`GET /compartilhamentos`).
class CompartilhamentoDoPaciente {
  final int id;
  final int tratamentoId;
  final String medicamento;
  final ProfissionalResumo? profissional;
  final StatusCompartilhamento status;
  final DateTime? criadoEm;

  const CompartilhamentoDoPaciente({
    required this.id,
    required this.tratamentoId,
    required this.medicamento,
    required this.profissional,
    required this.status,
    this.criadoEm,
  });

  factory CompartilhamentoDoPaciente.fromJson(Map<String, dynamic> json) =>
      CompartilhamentoDoPaciente(
        id: json['id'] as int,
        tratamentoId: json['tratamento_id'] as int,
        medicamento: json['medicamento'] as String? ?? '',
        profissional: ProfissionalResumo.doJson(json),
        status: StatusCompartilhamento.doBackend(json['status'] as String?),
        criadoEm: DateTime.tryParse('${json['criado_em'] ?? ''}'),
      );
}

/// Pedido de acesso que espera o paciente decidir.
class PedidoDeAcesso {
  final int compartilhamentoId;
  final String medicamento;
  final ProfissionalResumo profissional;
  final DateTime? pedidoEm;

  const PedidoDeAcesso({
    required this.compartilhamentoId,
    required this.medicamento,
    required this.profissional,
    this.pedidoEm,
  });

  factory PedidoDeAcesso.fromJson(Map<String, dynamic> json) => PedidoDeAcesso(
    compartilhamentoId: json['compartilhamento_id'] as int,
    medicamento: json['medicamento'] as String? ?? '',
    profissional:
        ProfissionalResumo.doJson(json) ??
        const ProfissionalResumo(nome: 'Profissional'),
    pedidoEm: DateTime.tryParse('${json['solicitado_em'] ?? ''}'),
  );
}

/// Tratamento que um paciente compartilhou com o profissional logado.
class TratamentoDePaciente {
  final int compartilhamentoId;
  final int pacienteId;
  final String pacienteNome;
  final Tratamento tratamento;

  const TratamentoDePaciente({
    required this.compartilhamentoId,
    required this.pacienteId,
    required this.pacienteNome,
    required this.tratamento,
  });

  factory TratamentoDePaciente.fromJson(Map<String, dynamic> json) =>
      TratamentoDePaciente(
        compartilhamentoId: json['compartilhamento_id'] as int,
        pacienteId: json['paciente_usuario_id'] as int,
        pacienteNome: json['paciente_nome'] as String? ?? 'Paciente',
        tratamento: Tratamento.fromJson({
          ...json,
          'id': json['tratamento_id'],
          'status': json['tratamento_status'],
        }),
      );
}

/// O que o profissional vê ao abrir um tratamento compartilhado.
class DetalheCompartilhado {
  final String pacienteNome;
  final Tratamento tratamento;
  final List<Dose> doses;

  const DetalheCompartilhado({
    required this.pacienteNome,
    required this.tratamento,
    required this.doses,
  });

  factory DetalheCompartilhado.fromJson(Map<String, dynamic> json) {
    final dados = json['tratamento'] as Map<String, dynamic>;
    final tratamento = Tratamento.fromJson(dados);
    return DetalheCompartilhado(
      pacienteNome: dados['paciente_nome'] as String? ?? 'Paciente',
      tratamento: tratamento,
      doses: [
        for (final item in dados['doses'] as List? ?? const [])
          Dose.fromJson(item as Map<String, dynamic>, tratamento),
      ]..sort((a, b) => b.agendadaPara.compareTo(a.agendadaPara)),
    );
  }
}
