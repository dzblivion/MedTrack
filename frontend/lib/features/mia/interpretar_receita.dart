import '../tratamentos/frequencia.dart';

/// A MIA devolve a frequência e a duração do jeito que estão escritas na
/// receita ("de 8 em 8 horas", "por 7 dias"). Aqui tentamos entender os
/// casos mais comuns para já preencher o formulário. O que não entender
/// fica em branco, e o texto original aparece como dica para a pessoa.

/// Duração lida da receita: dias, ou uso contínuo.
typedef DuracaoLida = ({int? dias, bool continuo});

const _numerosPorExtenso = {
  'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'tres': 3, 'quatro': 4,
  'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9, 'dez': 10,
  'doze': 12, 'quinze': 15, 'vinte': 20, 'trinta': 30,
};

/// Horários sugeridos para "N vezes ao dia" (a pessoa ajusta depois).
const _horariosPorVezes = {
  1: ['08:00'],
  2: ['08:00', '20:00'],
  3: ['08:00', '14:00', '20:00'],
  4: ['08:00', '12:00', '16:00', '20:00'],
};

/// Primeira dose sugerida nos tratamentos por intervalo.
const _primeiraDose = '08:00';

/// Minúsculas, sem acentos e com os números por extenso viram dígitos.
String _normalizar(String texto) {
  const acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ç': 'c',
  };
  var t = texto.toLowerCase();
  acentos.forEach((de, para) => t = t.replaceAll(de, para));
  return t.replaceAllMapped(
    RegExp(r'\b(' + _numerosPorExtenso.keys.join('|') + r')\b'),
    (m) => '${_numerosPorExtenso[m[1]]}',
  );
}

/// "de 8 em 8 horas", "8/8h", "a cada 12 horas", "3 vezes ao dia",
/// "1x ao dia", "a cada 2 dias", "1 vez ao dia", "diariamente".
Frequencia? interpretarFrequencia(String? texto) {
  if (texto == null || texto.trim().isEmpty) return null;
  final t = _normalizar(texto);

  // Intervalo em horas: "de 8 em 8 horas", "8/8h", "a cada 8 h".
  final horas = RegExp(r'(\d+)\s*(?:/|em)\s*(\d+)\s*(?:h\b|hora)').firstMatch(t) ??
      RegExp(r'cada\s*(\d+)\s*(?:h\b|hora)').firstMatch(t);
  if (horas != null) {
    final valor = int.parse(horas.group(horas.groupCount)!);
    if (valor == 24) return _diario(1);
    if (valor > 0) {
      return Frequencia(
        tipo: TipoFrequencia.intervaloHoras,
        horarios: const [_primeiraDose],
        intervaloValor: valor,
      );
    }
  }

  // Intervalo em dias: "a cada 2 dias", "de 3 em 3 dias".
  final dias = RegExp(r'(\d+)\s*em\s*(\d+)\s*dia').firstMatch(t) ??
      RegExp(r'cada\s*(\d+)\s*dia').firstMatch(t);
  if (dias != null) {
    final valor = int.parse(dias.group(dias.groupCount)!);
    if (valor == 1) return _diario(1);
    if (valor > 1) {
      return Frequencia(
        tipo: TipoFrequencia.intervaloDias,
        horarios: const [_primeiraDose],
        intervaloValor: valor,
      );
    }
  }

  // "3 vezes ao dia", "2x ao dia", "1 vez por dia", "2x/dia".
  final vezes = RegExp(r'(\d+)\s*(?:x|vez|vezes)\s*(?:ao|por|/|a)?\s*dia')
      .firstMatch(t);
  if (vezes != null) {
    final n = int.parse(vezes.group(1)!);
    if (_horariosPorVezes.containsKey(n)) return _diario(n);
    if (n > 0 && 24 % n == 0) {
      return Frequencia(
        tipo: TipoFrequencia.intervaloHoras,
        horarios: const [_primeiraDose],
        intervaloValor: 24 ~/ n,
      );
    }
  }

  if (RegExp(r'diariamente|todos os dias|todo dia|ao dia').hasMatch(t)) {
    return _diario(1);
  }
  return null;
}

Frequencia _diario(int vezes) => Frequencia(
      tipo: TipoFrequencia.diario,
      horarios: _horariosPorVezes[vezes]!,
    );

/// "por 7 dias", "durante 2 semanas", "por 1 mês", "uso contínuo".
DuracaoLida? interpretarDuracao(String? texto) {
  if (texto == null || texto.trim().isEmpty) return null;
  final t = _normalizar(texto);

  if (RegExp(r'continu|indeterminad|sem data|uso cronico').hasMatch(t)) {
    return (dias: null, continuo: true);
  }

  final quantidade = RegExp(r'(\d+)\s*(dia|semana|mes)').firstMatch(t);
  if (quantidade == null) return null;
  final n = int.parse(quantidade.group(1)!);
  final dias = switch (quantidade.group(2)) {
    'semana' => n * 7,
    'mes' => n * 30,
    _ => n,
  };
  return dias > 0 ? (dias: dias, continuo: false) : null;
}
