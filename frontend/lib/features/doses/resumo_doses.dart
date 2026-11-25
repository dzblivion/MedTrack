import 'dose.dart';

/// Contagem das doses de um tratamento para o detalhe.
class ResumoDoses {
  /// Todas as doses que o backend criou para o tratamento.
  final int total;
  final int tomadas;

  /// Marcadas como "Não tomei".
  final int naoTomadas;

  /// Passaram do horário e ninguém marcou (podem ser corrigidas no
  /// Histórico).
  final int semRegistro;

  /// Ainda vão chegar.
  final int restantes;

  const ResumoDoses({
    required this.total,
    required this.tomadas,
    required this.naoTomadas,
    required this.semRegistro,
    required this.restantes,
  });

  factory ResumoDoses.de(List<Dose> doses, DateTime agora) {
    var tomadas = 0, naoTomadas = 0, semRegistro = 0, restantes = 0;
    for (final dose in doses) {
      switch (dose.status) {
        case StatusDose.tomada:
          tomadas++;
        case StatusDose.naoTomada:
          naoTomadas++;
        case StatusDose.pendente when dose.atrasada(agora):
          semRegistro++;
        case StatusDose.pendente:
          restantes++;
      }
    }
    return ResumoDoses(
      total: doses.length,
      tomadas: tomadas,
      naoTomadas: naoTomadas,
      semRegistro: semRegistro,
      restantes: restantes,
    );
  }

  /// Perdidas para a adesão: não tomadas + sem registro.
  int get perdidas => naoTomadas + semRegistro;

  /// Já houve alguma dose cujo horário passou.
  bool get comecou => tomadas + perdidas > 0;

  /// De 0 a 1.
  double get fracaoTomadas => total == 0 ? 0 : tomadas / total;
}
