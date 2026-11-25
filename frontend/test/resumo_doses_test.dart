import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/doses/dose.dart';
import 'package:frontend/features/doses/resumo_doses.dart';

import 'helpers.dart';

void main() {
  final agora = DateTime(2026, 11, 19, 15);

  test('conta tomadas, não tomadas, sem registro e restantes', () {
    final resumo = ResumoDoses.de([
      doseExemplo(id: 1, em: DateTime(2026, 11, 18, 8), status: StatusDose.tomada),
      doseExemplo(id: 2, em: DateTime(2026, 11, 18, 20), status: StatusDose.tomada),
      doseExemplo(id: 3, em: DateTime(2026, 11, 19, 8), status: StatusDose.naoTomada),
      // Passou do horário sem marcar.
      doseExemplo(id: 4, em: DateTime(2026, 11, 19, 12)),
      // Ainda vai chegar.
      doseExemplo(id: 5, em: DateTime(2026, 11, 19, 20)),
      doseExemplo(id: 6, em: DateTime(2026, 11, 20, 8)),
    ], agora);

    expect(resumo.total, 6);
    expect(resumo.tomadas, 2);
    expect(resumo.naoTomadas, 1);
    expect(resumo.semRegistro, 1);
    expect(resumo.restantes, 2);
    expect(resumo.perdidas, 2);
    expect(resumo.fracaoTomadas, closeTo(2 / 6, 0.001));
    expect(resumo.comecou, isTrue);
  });

  test('antes da primeira dose ainda não começou', () {
    final resumo = ResumoDoses.de([
      doseExemplo(em: DateTime(2026, 11, 20, 8)),
    ], agora);

    expect(resumo.comecou, isFalse);
    expect(resumo.restantes, 1);
  });

  test('a dose no próprio minuto ainda não conta como sem registro', () {
    final resumo = ResumoDoses.de([
      doseExemplo(em: DateTime(2026, 11, 19, 14, 59, 30)),
    ], agora);

    expect(resumo.semRegistro, 0);
    expect(resumo.restantes, 1);
  });
}
