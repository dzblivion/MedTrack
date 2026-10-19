abstract final class Rotas {
  static const splash = '/splash';
  static const login = '/login';
  static const cadastro = '/cadastro';
  static const recuperarSenha = '/recuperar-senha';
  static const verificarCodigo = '/recuperar-senha/codigo';
  static const novaSenha = '/recuperar-senha/nova-senha';
  static const inicio = '/inicio';
  static const tratamentos = '/tratamentos';
  static const novoTratamento = '/tratamentos/novo';
  static String tratamento(int id) => '/tratamentos/$id';
  static String editarTratamento(int id) => '/tratamentos/$id/editar';
  static const historico = '/historico';
  static const perfil = '/perfil';
}
