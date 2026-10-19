import '../../core/formatos.dart';

/// Mesmas regras do backend (routes/tratamento.py), checadas antes de enviar.
class TratamentoValidators {
  static const limiteDuracao = 3650;

  static String? medicamento(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe o medicamento';
    if (texto.length > 150) return 'Use no máximo 150 caracteres';
    return null;
  }

  static String? Function(String?) numeroPositivo(String rotulo) {
    return (valor) {
      if (valor == null || valor.trim().isEmpty) return 'Informe $rotulo';
      final numero = lerNumero(valor);
      if (numero == null) return 'Número inválido';
      if (numero <= 0) return 'Deve ser maior que zero';
      return null;
    };
  }

  static String? duracao(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Informe a duração';
    final dias = int.tryParse(valor.trim());
    if (dias == null || dias < 1 || dias > limiteDuracao) {
      return 'Entre 1 e $limiteDuracao dias';
    }
    return null;
  }
}
