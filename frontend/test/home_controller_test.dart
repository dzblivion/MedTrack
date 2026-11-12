import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/doses/dose_repository.dart';
import 'package:frontend/features/home/home_controller.dart';

import 'helpers.dart';

/// Cada busca fica pendurada até o teste decidir a resposta.
class DosesManuais extends DoseRepository {
  final respostas = <Completer<List<Dose>>>[];

  DosesManuais() : super(ApiClient(), TratamentoFake());

  @override
  Future<List<Dose>> doDia(DateTime dia) {
    final resposta = Completer<List<Dose>>();
    respostas.add(resposta);
    return resposta.future;
  }
}

void main() {
  test('uma busca antiga que termina por último não sobrescreve a nova', () async {
    final repositorio = DosesManuais();
    final controller = HomeController(repositorio);
    addTearDown(controller.dispose);

    final antiga = controller.carregar();
    final nova = controller.carregar();

    final agora = DateTime.now();
    repositorio.respostas[1].complete([
      doseExemplo(id: 2, medicamento: 'Nova', em: agora),
    ]);
    await nova;
    repositorio.respostas[0].complete([
      doseExemplo(id: 1, medicamento: 'Antiga', em: agora),
    ]);
    await antiga;

    expect([for (final d in controller.doses) d.medicamento], ['Nova']);
    expect(controller.carregando, isFalse);
  });
}
