import '../../core/api/api_client.dart';
import 'medicamento_lido.dart';

class MiaRepository {
  final ApiClient _api;

  MiaRepository(this._api);

  /// Quanto o app espera a MIA. Normalmente ela leva uns 10 s, mas a
  /// Azure e o Gemini às vezes demoram (serviço ocupado, conexão lenta).
  static const espera = Duration(seconds: 90);

  /// Manda a foto (ou PDF) da receita para a MIA. Nada é salvo: volta só
  /// o que ela leu, para a pessoa conferir.
  Future<ResultadoMia> lerPrescricao({
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    final dados = await _api.enviarArquivo(
      '/tratamentos/ler-prescricao',
      campo: 'arquivo',
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      espera: espera,
    );
    return ResultadoMia.fromJson(dados);
  }
}
