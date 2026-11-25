import 'package:flutter/foundation.dart';

import '../auth/sessao_controller.dart';
import 'foto_perfil_repository.dart';

/// A foto de perfil de quem está logado, usada no avatar de todas as abas.
/// Busca ao entrar e esquece ao sair.
class FotoPerfilController extends ChangeNotifier {
  final FotoPerfilRepository _repositorio;
  final SessaoController _sessao;

  Uint8List? _foto;
  bool _enviando = false;
  bool _buscou = false;

  FotoPerfilController(this._repositorio, this._sessao) {
    _sessao.addListener(_acompanharSessao);
    _acompanharSessao();
  }

  Uint8List? get foto => _foto;
  bool get temFoto => _foto != null;

  /// Enviando ou removendo (para mostrar o carregando no avatar).
  bool get enviando => _enviando;

  void _acompanharSessao() {
    if (_sessao.logado && !_buscou) {
      _buscou = true;
      _buscar();
    } else if (!_sessao.logado && _buscou) {
      _buscou = false;
      _foto = null;
      notifyListeners();
    }
  }

  /// Sem foto (ou se falhar), o avatar só mostra a inicial.
  Future<void> _buscar() async {
    try {
      final foto = await _repositorio.buscar();
      // Saiu enquanto buscava: não mostra a foto de quem saiu.
      if (!_sessao.logado) return;
      _foto = foto;
      notifyListeners();
    } catch (_) {}
  }

  /// Envia e mostra a versão que o backend salvou. Erros da API sobem
  /// para a tela mostrar (ex.: "Aguarde antes de trocar a foto").
  Future<void> trocar({required Uint8List bytes, required String nome}) =>
      _ocupado(() async {
        await _repositorio.enviar(bytes: bytes, nome: nome);
        // A foto salva é a reduzida pelo backend; se a busca falhar, mostra
        // a que foi escolhida.
        _foto = await _repositorio.buscar().catchError((_) => bytes) ?? bytes;
      });

  Future<void> remover() => _ocupado(() async {
        await _repositorio.remover();
        _foto = null;
      });

  Future<void> _ocupado(Future<void> Function() acao) async {
    _enviando = true;
    notifyListeners();
    try {
      await acao();
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessao.removeListener(_acompanharSessao);
    super.dispose();
  }
}
