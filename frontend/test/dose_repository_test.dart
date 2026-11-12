import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/doses/dose_repository.dart';
import 'package:frontend/features/tratamentos/tratamento.dart';

import 'helpers.dart';

/// Responde as rotas de doses com o formato real do backend.
class ApiDosesFake extends ApiClient {
  final Map<String, Map<String, dynamic>> respostas;
  final pedidos = <String>[];
  ({String path, Map<String, dynamic> body})? patchFeito;

  ApiDosesFake(this.respostas);

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    pedidos.add(path);
    return respostas[path]!;
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    patchFeito = (path: path, body: body);
    return {};
  }
}

void main() {
  final hoje = DateTime(2026, 11, 12);

  Map<String, dynamic> dose(int id, String quando, String status) =>
      {'id': id, 'agendada_para': quando, 'status': status, 'vencida': false};

  test('junta as doses de hoje dos tratamentos ativos, em ordem', () async {
    final api = ApiDosesFake({
      '/tratamentos/1/doses': {
        'doses_atrasadas': [dose(10, '2026-11-12T08:00:00', 'pendente')],
        'proximas_doses': [dose(11, '2026-11-13T08:00:00', 'pendente')],
        'historico': [dose(9, '2026-11-11T08:00:00', 'tomada')],
      },
      '/tratamentos/2/doses': {
        'doses_atrasadas': [],
        'proximas_doses': [dose(20, '2026-11-12T20:00:00', 'pendente')],
        'historico': [dose(19, '2026-11-12T06:30:00', 'nao_tomada')],
      },
    });
    final tratamentos = TratamentoFake([
      tratamentoExemplo(id: 1, medicamento: 'Losartana'),
      tratamentoExemplo(id: 2, medicamento: 'Dipirona', semDosagem: true),
      tratamentoExemplo(
        id: 3,
        medicamento: 'Pausado',
        status: StatusTratamento.pausado,
      ),
    ]);

    final doses = await DoseRepository(api, tratamentos).doDia(hoje);

    // O pausado nem é consultado.
    expect(api.pedidos, ['/tratamentos/1/doses', '/tratamentos/2/doses']);
    expect([for (final d in doses) d.id], [19, 10, 20]);
    expect(doses[0].status, StatusDose.naoTomada);
    expect(doses[0].medicamento, 'Dipirona');
    expect(doses[0].detalhe, '1 por dose');
    expect(doses[1].detalhe, '500 mg · 1 por dose');
    expect(doses[1].horario, '08:00');
  });

  test('registrar manda o status no formato do backend', () async {
    final api = ApiDosesFake({});
    final repositorio = DoseRepository(api, TratamentoFake());

    await repositorio.registrar(5, tomada: false);

    expect(api.patchFeito?.path, '/doses/5');
    expect(api.patchFeito?.body, {'status': 'nao_tomada'});
  });

  test('só deixa registrar a partir do horário', () {
    final d = doseExemplo(em: DateTime(2026, 11, 12, 8));

    expect(d.podeRegistrar(DateTime(2026, 11, 12, 7, 59)), isFalse);
    expect(d.podeRegistrar(DateTime(2026, 11, 12, 8)), isTrue);
  });

  test('só fica atrasada 1 minuto depois do horário', () {
    final d = doseExemplo(em: DateTime(2026, 11, 12, 8));

    expect(d.atrasada(DateTime(2026, 11, 12, 8)), isFalse);
    expect(d.atrasada(DateTime(2026, 11, 12, 8, 0, 59)), isFalse);
    expect(d.atrasada(DateTime(2026, 11, 12, 8, 1)), isTrue);
    expect(d.atrasada(DateTime(2026, 11, 12, 9)), isTrue);
  });
}
