import '../../core/formatos.dart';

/// Mesmas regras do backend (routes/tratamento.py), checadas antes de enviar.
class TratamentoValidators {
  static const limiteDuracao = 3650;
  static const limiteIntervaloHoras = 24 * limiteDuracao;

  static String? medicamento(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Informe o medicamento';
    if (texto.length > 150) return 'Use no máximo 150 caracteres';
    return null;
  }

  /// Para listas de opção: nada escolhido mostra [mensagem].
  static String? Function(String?) escolha(String mensagem) =>
      (valor) => valor == null ? mensagem : null;

  static String? Function(String?) numeroPositivo(
    String rotulo, {
    bool obrigatorio = true,
  }) {
    return (valor) {
      if (valor == null || valor.trim().isEmpty) {
        return obrigatorio ? 'Informe $rotulo' : null;
      }
      final numero = lerNumero(valor);
      if (numero == null) return 'Número inválido';
      if (numero <= 0) return 'Deve ser maior que zero';
      return null;
    };
  }

  /// Só é pedida em "Com data de término"; o uso contínuo não tem duração.
  static String? duracao(String? valor) =>
      _inteiro(valor, 'Informe a duração', limiteDuracao, 'dias');

  static String? Function(String?) intervalo({required bool emDias}) =>
      (valor) => emDias
          ? _inteiro(valor, 'Informe o intervalo', limiteDuracao, 'dias')
          : _inteiro(
              valor,
              'Informe o intervalo',
              limiteIntervaloHoras,
              'horas',
            );

  static String? _inteiro(
    String? valor,
    String vazio,
    int limite,
    String unidade,
  ) {
    if (valor == null || valor.trim().isEmpty) return vazio;
    final numero = int.tryParse(valor.trim());
    if (numero == null || numero < 1 || numero > limite) {
      return 'Entre 1 e $limite $unidade';
    }
    return null;
  }
}
