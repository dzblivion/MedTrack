/// Dados extras de quem se cadastra como profissional de saúde.
typedef DadosProfissional = ({
  String profissao,
  String registro,
  String ufRegistro,
});

/// O que foi preenchido no cadastro. Fica guardado enquanto a pessoa
/// confirma o e-mail e só é enviado junto com o código.
class DadosCadastro {
  final String nome;
  final String email;
  final String senha;

  /// Nulo para usuário comum.
  final DadosProfissional? profissional;

  const DadosCadastro({
    required this.nome,
    required this.email,
    required this.senha,
    this.profissional,
  });

  Map<String, dynamic> toJson(String codigo) {
    final p = profissional;
    return {
      'nome': nome,
      'email': email,
      'senha': senha,
      'codigo': codigo,
      if (p != null) ...{
        'profissao': p.profissao,
        'registro': p.registro,
        'uf_registro': p.ufRegistro,
      },
    };
  }
}
