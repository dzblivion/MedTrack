import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'avatar_usuario.dart';

/// Avatar com a inicial + nome, no topo das abas do app (como no Figma).
class CabecalhoUsuario extends StatelessWidget {
  final String nome;
  final String? subtitulo;
  final Widget? acao;

  /// No Perfil: tocar no avatar troca a foto.
  final VoidCallback? onTocarAvatar;

  const CabecalhoUsuario({
    super.key,
    required this.nome,
    this.subtitulo,
    this.acao,
    this.onTocarAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarUsuario(nome: nome, onTap: onTocarAvatar),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitulo == null)
                Text(
                  'Olá,',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.gray,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitulo != null)
                Text(
                  subtitulo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.gray,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        ?acao,
      ],
    );
  }
}
