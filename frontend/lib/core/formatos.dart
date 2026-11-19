/// "500" para 500.0 e "0,5" para 0.5 (padrão brasileiro).
String formatarNumero(double valor) {
  if (valor == valor.roundToDouble()) return valor.toInt().toString();
  return valor
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

/// "05/10".
String formatarDiaMes(DateTime data) =>
    '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}';

/// "05/10/2026".
String formatarData(DateTime data) => '${formatarDiaMes(data)}/${data.year}';

/// "2026-10-05": formato de data que a API aceita.
String formatarDataApi(DateTime data) =>
    '${data.year}-${_doisDigitos(data.month)}-${_doisDigitos(data.day)}';

/// Aceita vírgula ou ponto como separador decimal ("0,5" ou "0.5").
double? lerNumero(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

const _diasDaSemana = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "quinta".
String diaDaSemana(DateTime data) => _diasDaSemana[data.weekday - 1];

/// "novembro".
String nomeDoMes(DateTime data) => _meses[data.month - 1];

/// "Novembro de 2026".
String formatarMesAno(DateTime data) {
  final mes = nomeDoMes(data);
  return '${mes[0].toUpperCase()}${mes.substring(1)} de ${data.year}';
}

String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');
