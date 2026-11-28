import 'package:flutter/foundation.dart';

import '../../core/mudancas.dart';
import '../auth/sessao_controller.dart';
import '../doses/dose.dart';
import '../doses/dose_repository.dart';
import 'botoes_dose.dart';
import 'notificador.dart';
import 'preferencias_lembretes.dart';

/// Agenda no celular um aviso no horário de cada dose pendente, com os
/// botões Tomei / Não tomei (e um aviso antes, se escolhido). Refaz a agenda
/// ao entrar, quando um tratamento muda e quando o app volta a ficar aberto;
/// ao sair da conta, apaga tudo.
class LembretesController extends ChangeNotifier {
  final Notificador _notificador;
  final ArmazenamentoLembretes _armazenamento;
  final DoseRepository _doses;
  final SessaoController _sessao;
  final Mudancas? _mudancas;

  /// Trocável nos testes, para fixar "agora".
  final DateTime Function() _relogio;

  /// O Android aceita um número limitado de alarmes por app; os mais
  /// próximos bastam, já que a agenda é refeita sempre que o app abre.
  static const maximoDoses = 50;

  PreferenciasLembretes _preferencias = const PreferenciasLembretes();
  bool? _permitido;
  int _agendados = 0;
  int _versao = 0;
  bool _estavaLogado = false;
  DateTime? _ultimaAgenda;
  bool _descartado = false;

  LembretesController(
    this._notificador,
    this._armazenamento,
    this._doses,
    this._sessao, {
    this._mudancas,
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now;

  PreferenciasLembretes get preferencias => _preferencias;

  /// Nulo quando não dá para saber (ex.: antes de perguntar).
  bool? get permitido => _permitido;

  /// Quantas doses estão com lembrete agendado.
  int get agendados => _agendados;
  bool get agendaNoAparelho => _notificador.agendaNoAparelho;

  /// Só o paciente tem doses para lembrar.
  bool get _deveAgendar =>
      _sessao.logado && _sessao.usuario?.ehProfissional != true;

  Future<void> iniciar() async {
    _preferencias = await _armazenamento.ler();
    await _notificador.iniciar();
    _estavaLogado = _sessao.logado;
    _sessao.addListener(_sessaoMudou);
    _mudancas?.addListener(reagendar);
    if (_deveAgendar && _preferencias.ativo) {
      await _pedirPermissaoNoCelular();
      await reagendar();
    }
  }

  Future<void> _sessaoMudou() async {
    final logado = _sessao.logado;
    if (logado == _estavaLogado) return;
    _estavaLogado = logado;
    if (!logado) {
      // Outra pessoa pode entrar neste aparelho.
      _versao++;
      _agendados = 0;
      await _notificador.cancelarTodos();
      _avisar();
    } else if (_deveAgendar && _preferencias.ativo) {
      await _pedirPermissaoNoCelular();
      await reagendar();
    }
  }

  /// No celular, perguntar logo ao entrar é o comum. No navegador só dá
  /// para perguntar quando a pessoa toca num botão (o de teste).
  Future<void> _pedirPermissaoNoCelular() async {
    if (!agendaNoAparelho) return;
    _permitido = await _notificador.permitido();
    if (_permitido == false) _permitido = await _notificador.pedirPermissao();
    _avisar();
  }

  /// Ao voltar para o app: refaz no máximo a cada 5 minutos (o backend
  /// pode ter criado doses novas para os tratamentos contínuos).
  Future<void> appVoltou() async {
    final ultima = _ultimaAgenda;
    final passou = ultima == null ? null : _relogio().difference(ultima);
    // Relógio voltou (ex.: a pessoa trocou a hora ou o fuso): refaz já.
    if (passou != null &&
        !passou.isNegative &&
        passou < const Duration(minutes: 5)) {
      return;
    }
    await reagendar();
  }

  Future<void> reagendar() async {
    if (!agendaNoAparelho) return;
    final versao = ++_versao;

    List<Dose> doses = const [];
    if (_deveAgendar && _preferencias.ativo) {
      try {
        doses = await _doses.proximas(_relogio());
      } catch (_) {
        // Sem internet: mantém os lembretes que já estavam agendados.
        return;
      }
    }
    // Outra agenda começou enquanto buscava: ela vale mais.
    if (versao != _versao) return;

    await _notificador.cancelarTodos();
    final agora = _relogio();
    final minutosAntes = _preferencias.minutosAntes;
    var agendados = 0;
    for (final dose in doses.take(maximoDoses)) {
      if (versao != _versao) return;
      // Principal: no horário, com os botões Tomei / Não tomei.
      await _notificador.agendar(
        id: _idPrincipal(dose),
        quando: dose.agendadaPara,
        titulo: 'Hora de tomar ${dose.medicamento}',
        texto: '${dose.detalhe} · ${dose.horario}',
        dados: dadosDoAviso(
          doseId: dose.id,
          medicamento: dose.medicamento,
          horario: dose.horario,
        ),
      );
      // Antecipado: só lembra (registrar só vale a partir do horário).
      final antes = dose.agendadaPara.subtract(
        Duration(minutes: minutosAntes),
      );
      if (minutosAntes > 0 && antes.isAfter(agora)) {
        await _notificador.agendar(
          id: _idAntecipado(dose),
          quando: antes,
          titulo: 'Daqui a $minutosAntes min: ${dose.medicamento}',
          texto: '${dose.detalhe} · ${dose.horario}',
        );
      }
      agendados++;
    }
    _agendados = agendados;
    _ultimaAgenda = agora;
    _avisar();
  }

  /// Dose marcada no app: tira o aviso dela (se ainda estiver na tela ou
  /// agendado).
  Future<void> doseRegistrada(Dose dose) async {
    if (!agendaNoAparelho) return;
    await _notificador.cancelar(_idPrincipal(dose));
    await _notificador.cancelar(_idAntecipado(dose));
  }

  Future<void> alterar(PreferenciasLembretes novas) async {
    final ligou = novas.ativo && !_preferencias.ativo;
    _preferencias = novas;
    _avisar();
    await _armazenamento.salvar(novas);
    if (ligou) await _pedirPermissaoNoCelular();
    await reagendar();
  }

  /// Mostra uma notificação agora, para conferir que estão chegando.
  /// Devolve falso se o aparelho não deixou.
  Future<bool> testar() async {
    final pode = await _notificador.pedirPermissao();
    _permitido = pode;
    _avisar();
    if (!pode) return false;
    await _notificador.mostrarAgora(
      titulo: 'MedTrack',
      texto: 'Tudo certo! É assim que os lembretes das doses vão aparecer.',
    );
    return true;
  }

  // Cada dose usa dois números: o aviso principal e o antecipado.
  static int _idPrincipal(Dose dose) => dose.id * 2;
  static int _idAntecipado(Dose dose) => dose.id * 2 + 1;

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _sessao.removeListener(_sessaoMudou);
    _mudancas?.removeListener(reagendar);
    super.dispose();
  }
}
