import 'dart:convert';

/// Botões do aviso "Hora de tomar X".
const acaoTomei = 'tomei';
const acaoNaoTomei = 'nao_tomei';

/// O que o aviso carrega para o botão saber qual dose registrar.
String dadosDoAviso({
  required int doseId,
  required String medicamento,
  required String horario,
}) => jsonEncode({'dose': doseId, 'remedio': medicamento, 'horario': horario});

/// Toque em "Tomei" ou "Não tomei" na notificação. Roda com o app fechado,
/// então recebe tudo de fora (o de verdade e os testes passam o seu).
/// Se não der para registrar, avisa numa notificação.
Future<void> tratarBotaoDaDose({
  required String? acao,
  required String? dados,
  required Future<String?> Function() lerToken,
  required Future<void> Function(String token, int doseId, bool tomada)
  registrar,
  required Future<void> Function(String titulo, String texto) avisarFalha,
  void Function(int doseId)? aoRegistrar,
}) async {
  final tomada = switch (acao) {
    acaoTomei => true,
    acaoNaoTomei => false,
    _ => null,
  };
  if (tomada == null || dados == null) return;

  final Map<String, dynamic> aviso;
  try {
    aviso = jsonDecode(dados) as Map<String, dynamic>;
  } catch (_) {
    return;
  }
  final doseId = aviso['dose'] as int;
  final remedio = aviso['remedio'] as String? ?? 'o remédio';
  final horario = aviso['horario'] as String?;

  try {
    final token = await lerToken();
    if (token == null) throw StateError('Sem login no aparelho.');
    await registrar(token, doseId, tomada);
    aoRegistrar?.call(doseId);
  } catch (_) {
    await avisarFalha(
      'Não foi possível registrar',
      'A dose de $remedio${horario == null ? '' : ' das $horario'} não foi '
          'marcada. Abra o MedTrack para registrar.',
    );
  }
}
