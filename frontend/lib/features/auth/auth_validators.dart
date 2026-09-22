class AuthValidators {
  static String? email(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!email.contains('@')) return 'E-mail deve conter @';
    return null;
  }

  static String? senhaObrigatoria(String? valor) {
    if (valor == null || valor.isEmpty) return 'Informe sua senha';
    return null;
  }

  static String? campoObrigatorio(String? valor, String rotulo) {
    if (valor == null || valor.trim().isEmpty) return 'Informe $rotulo';
    return null;
  }

  static String? nome(String? valor) => campoObrigatorio(valor, 'seu nome');

  static String? novaSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Crie uma senha';
    if (valor.length < 8) return 'A senha deve ter ao menos 8 caracteres';
    return null;
  }

  static String? Function(String?) confirmarSenha(
    String Function() senhaOriginal,
  ) {
    return (valor) {
      if (valor == null || valor.isEmpty) return 'Confirme sua senha';
      if (valor != senhaOriginal()) return 'As senhas não coincidem';
      return null;
    };
  }
}
