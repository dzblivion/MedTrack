abstract final class Rotas {
  static const splash = '/splash';
  static const login = '/login';
  static const cadastro = '/cadastro';
  static const confirmarCadastro = '/cadastro/confirmar';
  static const recuperarSenha = '/recuperar-senha';
  static const verificarCodigo = '/recuperar-senha/codigo';
  static const novaSenha = '/recuperar-senha/nova-senha';
  static const inicio = '/inicio';
  static const tratamentos = '/tratamentos';
  static const novoTratamento = '/tratamentos/novo';
  static String tratamento(int id) => '/tratamentos/$id';
  static String editarTratamento(int id) => '/tratamentos/$id/editar';
  static const historico = '/historico';

  /// Histórico só das doses de um tratamento, aberto por cima do detalhe.
  static String historicoDoTratamento(int id) => '/tratamentos/$id/historico';
  static const perfil = '/perfil';
  static const termos = '/termos';
  static const privacidade = '/privacidade';
}
