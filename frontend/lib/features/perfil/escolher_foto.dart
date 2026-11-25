import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Foto escolhida para o perfil.
typedef FotoEscolhida = ({Uint8List bytes, String nome});

/// Tira uma foto ([camera]) ou escolhe da galeria. Nulo se desistiu.
/// Trocável nos testes, onde não há câmera nem galeria.
typedef EscolherFoto = Future<FotoEscolhida?> Function({required bool camera});

/// Já reduz a foto no aparelho (o backend aceita até 5 MB e guarda no
/// máximo 1024 px), deixando o envio mais rápido no celular.
Future<FotoEscolhida?> escolherFotoDoAparelho({required bool camera}) async {
  final arquivo = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (arquivo == null) return null;
  // No navegador a foto pode vir sem nome; o backend só exige que tenha um.
  final nome = arquivo.name.contains('.') ? arquivo.name : 'foto.jpg';
  return (bytes: await arquivo.readAsBytes(), nome: nome);
}
