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
}
