import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Como a pessoa quer ser lembrada das doses. Fica salvo no aparelho.
class PreferenciasLembretes {
  /// Avisar no horário de cada dose (com os botões Tomei / Não tomei).
  final bool ativo;

  /// Aviso extra, só para lembrar, tantos minutos antes (0 = sem aviso
  /// extra). O principal continua sendo no horário.
  final int minutosAntes;

  const PreferenciasLembretes({this.ativo = true, this.minutosAntes = 0});

  static const opcoesMinutosAntes = [0, 5, 15, 30];

  PreferenciasLembretes copyWith({bool? ativo, int? minutosAntes}) =>
      PreferenciasLembretes(
        ativo: ativo ?? this.ativo,
        minutosAntes: minutosAntes ?? this.minutosAntes,
      );

  Map<String, dynamic> toJson() => {
    'ativo': ativo,
    'minutos_antes': minutosAntes,
  };

  factory PreferenciasLembretes.fromJson(Map<String, dynamic> json) =>
      PreferenciasLembretes(
        ativo: json['ativo'] as bool? ?? true,
        minutosAntes: json['minutos_antes'] as int? ?? 0,
      );
}

/// Guarda as preferências no aparelho (os testes usam uma versão em memória).
class ArmazenamentoLembretes {
  static const _chave = 'preferencias_lembretes';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<PreferenciasLembretes> ler() async {
    try {
      final texto = await _storage.read(key: _chave);
      if (texto == null) return const PreferenciasLembretes();
      return PreferenciasLembretes.fromJson(
        jsonDecode(texto) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PreferenciasLembretes();
    }
  }

  Future<void> salvar(PreferenciasLembretes preferencias) => _storage.write(
    key: _chave,
    value: jsonEncode(preferencias.toJson()),
  );
}
