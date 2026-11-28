import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'botoes_dose.dart';
import 'segundo_plano.dart';

/// Mostra e agenda notificações no aparelho. Separado para os testes
/// trocarem por um falso.
abstract class Notificador {
  /// No celular os lembretes ficam agendados mesmo com o app fechado. O
  /// navegador só mostra notificações na hora (ex.: a de teste).
  bool get agendaNoAparelho;

  Future<void> iniciar();

  /// Pede para mostrar notificações. Devolve se pode.
  Future<bool> pedirPermissao();

  /// Nulo quando não dá para saber.
  Future<bool?> permitido();

  /// Com [dados] (ver `dadosDoAviso`), o aviso ganha os botões "Tomei" e
  /// "Não tomei"; sem, é só um lembrete.
  Future<void> agendar({
    required int id,
    required DateTime quando,
    required String titulo,
    required String texto,
    String? dados,
  });

  Future<void> mostrarAgora({required String titulo, required String texto});

  Future<void> cancelar(int id);

  Future<void> cancelarTodos();
}

/// O de verdade, com o flutter_local_notifications.
class NotificadorLocal implements Notificador {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _iniciado = false;
  int _proximoIdImediato = 2000000000;

  static NotificationDetails _detalhes({bool comBotoes = false}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'lembretes_doses',
          'Lembretes de doses',
          channelDescription: 'Avisos na hora de tomar cada medicamento',
          importance: Importance.max,
          priority: Priority.high,
          // O Android só aceita a silhueta (uma cor só), que ele pinta com
          // [color]: é a logo oficial em uma cor.
          icon: 'ic_notificacao',
          color: const Color(0xFF27B8B5),
          // Registram a dose sem abrir o app (ver segundo_plano_io.dart).
          // O Android não deixa mudar o fundo dos botões; o símbolo e a cor
          // do texto (as mesmas dos botões do Início) dão o destaque.
          actions: comBotoes
              ? const [
                  AndroidNotificationAction(
                    acaoTomei,
                    '✓ Tomei',
                    titleColor: Color(0xFF167C80),
                  ),
                  AndroidNotificationAction(
                    acaoNaoTomei,
                    '✕ Não tomei',
                    titleColor: Color(0xFFD9535B),
                  ),
                ]
              : null,
        ),
      );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  WebFlutterLocalNotificationsPlugin? get _web => _plugin
      .resolvePlatformSpecificImplementation<
        WebFlutterLocalNotificationsPlugin
      >();

  bool get _noAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get agendaNoAparelho => _noAndroid;

  @override
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notificacao'),
        ),
        onDidReceiveBackgroundNotificationResponse:
            responderBotaoEmSegundoPlano,
      );
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  @override
  Future<bool> pedirPermissao() async {
    await iniciar();
    try {
      if (kIsWeb) return await _web?.requestNotificationsPermission() ?? false;
      if (_noAndroid) {
        return await _android?.requestNotificationsPermission() ?? false;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool?> permitido() async {
    try {
      if (kIsWeb) {
        return _web?.permissionStatus == WebNotificationPermission.granted;
      }
      if (_noAndroid) return await _android?.areNotificationsEnabled();
    } catch (_) {}
    return null;
  }

  @override
  Future<void> agendar({
    required int id,
    required DateTime quando,
    required String titulo,
    required String texto,
    String? dados,
  }) async {
    if (!_noAndroid) return;
    // O alarme exato garante o aviso no minuto certo; sem a permissão,
    // o Android avisa perto do horário.
    final exato = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: texto,
      // Só importa o instante; UTC evita depender do fuso do aparelho.
      scheduledDate: tz.TZDateTime.from(quando, tz.UTC),
      notificationDetails: _detalhes(comBotoes: dados != null),
      payload: dados,
      androidScheduleMode: exato
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> mostrarAgora({
    required String titulo,
    required String texto,
  }) async {
    await iniciar();
    await _plugin.show(
      id: _proximoIdImediato++,
      title: titulo,
      body: texto,
      notificationDetails: _detalhes(),
    );
  }

  @override
  Future<void> cancelar(int id) async {
    if (_noAndroid) await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelarTodos() async {
    if (_noAndroid) await _plugin.cancelAll();
  }
}
