import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/perfil/foto_perfil_controller.dart';
import '../theme/app_theme.dart';

/// Círculo com a foto de perfil, ou a inicial do nome se não houver foto.
/// Com [onTap], ganha o selo de câmera (trocar a foto, no Perfil).
class AvatarUsuario extends StatelessWidget {
  final String nome;
  final double tamanho;
  final VoidCallback? onTap;

  const AvatarUsuario({
    super.key,
    required this.nome,
    this.tamanho = 48,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FotoPerfilController>();
    final foto = controller.foto;
    final inicial = nome.isEmpty ? '?' : nome[0].toUpperCase();

    final circulo = Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ciano, Color.fromARGB(255, 25, 136, 139)],
        ),
      ),
      child: controller.enviando
          ? SizedBox.square(
              dimension: tamanho * 0.4,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : foto != null
              ? Image.memory(
                  foto,
                  width: tamanho,
                  height: tamanho,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'Foto de perfil',
                  // Imagem com defeito: volta para a inicial.
                  errorBuilder: (_, _, _) => _Inicial(inicial, tamanho),
                )
              : _Inicial(inicial, tamanho),
    );

    if (onTap == null) return circulo;

    return Semantics(
      button: true,
      label: 'Trocar foto de perfil',
      child: GestureDetector(
        onTap: controller.enviando ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            circulo,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cianoClaro),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: AppColors.darkCiano,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inicial extends StatelessWidget {
  final String letra;
  final double tamanho;

  const _Inicial(this.letra, this.tamanho);

  @override
  Widget build(BuildContext context) {
    return Text(
      letra,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: tamanho * 0.42,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
