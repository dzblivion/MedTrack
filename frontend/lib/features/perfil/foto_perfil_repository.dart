import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

class FotoPerfilRepository {
  static const _rota = '/usuarios/me/foto';

  final ApiClient _api;

  FotoPerfilRepository(this._api);

  /// A foto (JPEG) ou nulo se a pessoa ainda não tem.
  Future<Uint8List?> buscar() => _api.baixar(_rota);

  /// O backend aceita JPG, PNG ou WEBP de até 5 MB e só deixa trocar de
  /// novo depois de 60 s (erro 429 com a mensagem para mostrar).
  Future<void> enviar({required List<int> bytes, required String nome}) =>
      _api.enviarArquivo(
        _rota,
        campo: 'foto',
        bytes: bytes,
        nomeArquivo: nome,
        metodo: 'PUT',
        espera: const Duration(seconds: 30),
      );

  Future<void> remover() => _api.delete(_rota);
}
