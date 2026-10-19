import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/cabecalho_usuario.dart';
import '../auth/sessao_controller.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  void _emBreve(BuildContext context) => AppSnackBar.info(context, 'Em breve.');

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<SessaoController>();
    final usuario = sessao.usuario;
    final nome = usuario?.nome ?? '';
    final email = usuario?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabecalhoUsuario(
              nome: nome,
              subtitulo: email,
              acao: FilledButton(
                onPressed: () => _emBreve(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ciano,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Editar perfil'),
              ),
            ),
            const _Titulo('Dados pessoais'),
            _DadoPessoal(icone: Icons.person_outline, texto: nome),
            _DadoPessoal(icone: Icons.alternate_email, texto: email),
            const _Titulo('Configurações'),
            _ItemConfiguracao(
              titulo: 'Notificações',
              descricao: 'Gerencie seus lembretes de medicamentos',
              onTap: () => _emBreve(context),
            ),
            _ItemConfiguracao(
              titulo: 'Alterar senha',
              descricao: 'Atualize a senha da sua conta',
              onTap: () => context.push(Rotas.recuperarSenha, extra: email),
            ),
            _ItemConfiguracao(
              titulo: 'Privacidade e dados',
              descricao: 'Gerencie o uso e compartilhamento dos seus dados',
              onTap: () => context.push(Rotas.privacidade),
            ),
            _ItemConfiguracao(
              titulo: 'Termos de uso',
              descricao: 'Consulte os termos do MedTrack',
              onTap: () => context.push(Rotas.termos),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: sessao.sair,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                  'Sair da conta',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.title,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DadoPessoal extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _DadoPessoal({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ciano,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemConfiguracao extends StatelessWidget {
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _ItemConfiguracao({
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.ciano,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  descricao,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
