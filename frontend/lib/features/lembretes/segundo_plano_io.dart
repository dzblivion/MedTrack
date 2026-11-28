import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/session_storage.dart';
import '../doses/dose_repository.dart';
import '../tratamentos/tratamento_repository.dart';
import 'botoes_dose.dart';
import 'notificador.dart';

/// Nome pelo qual o app aberto escuta "uma dose foi registrada pela
/// notificação" (para o Início atualizar na hora).
const _canal = 'medtrack_dose_registrada';

/// Toque em "Tomei" / "Não tomei". O Android acorda só esta parte do app,
/// separada da tela: por isso lê o login salvo e cria a sua conexão.
@pragma('vm:entry-point')
Future<void> responderBotaoEmSegundoPlano(NotificationResponse resposta) async {
  DartPluginRegistrant.ensureInitialized();
  final notificador = NotificadorLocal();
  await tratarBotaoDaDose(
    acao: resposta.actionId,
    dados: resposta.payload,
    lerToken: () async => (await SessionStorage().ler())?.token,
    registrar: (token, doseId, tomada) {
      final api = ApiClient()..token = token;
      return DoseRepository(
        api,
        TratamentoRepository(api),
      ).registrar(doseId, tomada: tomada);
    },
    avisarFalha: (titulo, texto) =>
        notificador.mostrarAgora(titulo: titulo, texto: texto),
    aoRegistrar: (doseId) =>
        IsolateNameServer.lookupPortByName(_canal)?.send(doseId),
  );
}

ReceivePort? _receptor;

/// O app aberto (mesmo minimizado) passa a saber quando uma dose foi
/// registrada pela notificação.
void ouvirDosesRegistradas(void Function() aoRegistrar) {
  pararDeOuvirDosesRegistradas();
  final receptor = ReceivePort();
  IsolateNameServer.registerPortWithName(receptor.sendPort, _canal);
  receptor.listen((_) => aoRegistrar());
  _receptor = receptor;
}

void pararDeOuvirDosesRegistradas() {
  IsolateNameServer.removePortNameMapping(_canal);
  _receptor?.close();
  _receptor = null;
}
