class Usuario {
  final int id;
  final String nome;
  final String email;
  final bool ehProfissional;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.ehProfissional = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nome: json['nome'] as String,
        email: json['email'] as String,
        ehProfissional: json['eh_profissional'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'eh_profissional': ehProfissional,
      };
}
