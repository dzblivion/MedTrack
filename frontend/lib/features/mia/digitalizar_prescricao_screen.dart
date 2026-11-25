import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/rotas.dart';
import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import 'anuncio_premiado.dart';
import 'mia_repository.dart';
import 'widgets/analise_mia_dialog.dart';
import 'widgets/moldura_tracejada.dart';

/// Foto (ou PDF) da receita escolhida para a MIA.
typedef FotoReceita = ({Uint8List bytes, String nome});

/// Abre a galeria/arquivos e devolve a imagem ou PDF escolhido.
typedef EscolherArquivo = Future<FotoReceita?> Function();

/// Câmera para fotografar a receita (ou escolher uma foto/PDF). Depois da
/// foto: janela do anúncio → a MIA lê → resultado.
class DigitalizarPrescricaoScreen extends StatefulWidget {
  /// Trocável nos testes (lá não há câmera nem seletor de arquivos).
  final EscolherArquivo escolherArquivo;

  const DigitalizarPrescricaoScreen({
    super.key,
    this.escolherArquivo = escolherArquivoDoAparelho,
  });

  @override
  State<DigitalizarPrescricaoScreen> createState() =>
      _DigitalizarPrescricaoScreenState();
}

/// Imagens e PDF, os formatos que o backend aceita.
Future<FotoReceita?> escolherArquivoDoAparelho() async {
  final arquivo = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (arquivo == null) return null;
  return (bytes: await arquivo.readAsBytes(), nome: arquivo.name);
}

class _DigitalizarPrescricaoScreenState
    extends State<DigitalizarPrescricaoScreen> {
  static const _fonte = 'Poppins';

  List<CameraDescription> _cameras = const [];
  CameraController? _camera;
  int _cameraAtual = 0;
  bool _flash = false;

  /// Sem câmera (navegador sem webcam, permissão negada, testes).
  String? _semCamera;
  FotoReceita? _foto;
  bool _enviando = false;

  /// Segundos desde que a foto foi para a MIA (mostra que não travou).
  int _segundosLendo = 0;
  Timer? _cronometro;

  @override
  void initState() {
    super.initState();
    _abrirCamera();
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _abrirCamera() async {
    try {
      // Listar as câmeras é instantâneo no celular; se não responder (ex.:
      // navegador sem suporte), cai para "escolher arquivo" em vez de travar.
      // (A permissão da câmera é pedida depois, ao abrir, sem limite.)
      _cameras = await availableCameras().timeout(const Duration(seconds: 5));
      if (_cameras.isEmpty) throw CameraException('sem-camera', null);
      // Prefere a câmera traseira.
      final traseira = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      await _usarCamera(traseira < 0 ? 0 : traseira);
    } catch (_) {
      if (mounted) {
        setState(() => _semCamera =
            'Câmera indisponível neste aparelho. Escolha uma foto ou PDF '
            'da receita.');
      }
    }
  }

  Future<void> _usarCamera(int indice) async {
    final anterior = _camera;
    final nova = CameraController(
      _cameras[indice],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await nova.initialize();
    await anterior?.dispose();
    if (!mounted) return nova.dispose();
    setState(() {
      _camera = nova;
      _cameraAtual = indice;
      _flash = false;
    });
  }

  Future<void> _trocarCamera() async {
    if (_cameras.length < 2) return;
    await _usarCamera((_cameraAtual + 1) % _cameras.length);
  }

  Future<void> _alternarFlash() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(_flash ? FlashMode.off : FlashMode.torch);
      setState(() => _flash = !_flash);
    } catch (_) {
      // Câmera sem flash (ex.: frontal ou navegador): ignora.
    }
  }

  Future<void> _fotografar() async {
    final camera = _camera;
    if (camera == null || camera.value.isTakingPicture) return;
    final arquivo = await camera.takePicture();
    final bytes = await arquivo.readAsBytes();
    if (mounted) setState(() => _foto = (bytes: bytes, nome: 'receita.jpg'));
  }

  Future<void> _escolherArquivo() async {
    final foto = await widget.escolherArquivo();
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  /// Depois da foto: a janela decide se assiste ao anúncio, vê o Plus ou
  /// cadastra à mão.
  Future<void> _usarFoto() async {
    final escolha = await mostrarAnaliseMia(context);
    if (!mounted || escolha == null) return;

    switch (escolha) {
      case EscolhaAnalise.anuncio:
        final assistiu = await context.read<AnuncioPremiado>().exibir(context);
        if (assistiu && mounted) await _enviar();
      case EscolhaAnalise.plus:
        await context.push(Rotas.plus);
      case EscolhaAnalise.manual:
        context.pushReplacement(Rotas.miaRevisar);
    }
  }

  Future<void> _enviar() async {
    final foto = _foto;
    if (foto == null) return;
    setState(() {
      _enviando = true;
      _segundosLendo = 0;
    });
    _cronometro?.cancel();
    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _segundosLendo++);
    });
    String erro;
    try {
      final resultado = await context.read<MiaRepository>().lerPrescricao(
            bytes: foto.bytes,
            nomeArquivo: foto.nome,
          );
      if (mounted) context.pushReplacement(Rotas.miaResultado, extra: resultado);
      return;
    } on ApiException catch (e) {
      erro = e.mensagem;
    } catch (_) {
      erro = 'Não foi possível ler a receita.';
    } finally {
      _cronometro?.cancel();
      // Tira o "lendo..." antes de mostrar o erro, não por baixo dele.
      if (mounted) setState(() => _enviando = false);
    }
    if (mounted) await _erroNaLeitura(erro);
  }

  /// A recompensa já foi ganha: tentar de novo não pede outro anúncio.
  Future<void> _erroNaLeitura(String mensagem) async {
    final acao = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('A MIA não conseguiu ler'),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop('manual'),
            child: const Text('Cadastrar manualmente'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop('tentar'),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (acao == 'tentar') return _enviar();
    if (acao == 'manual') context.pushReplacement(Rotas.miaRevisar);
  }

  @override
  Widget build(BuildContext context) {
    const branco = TextStyle(fontFamily: _fonte, color: Colors.white);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.ciano, Color(0xFF1B4F55)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _cabecalho(),
                  Expanded(child: _areaDaFoto(branco)),
                  const SizedBox(height: 16),
                  _foto == null ? _controlesCamera() : _controlesFoto(),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: branco.copyWith(fontSize: 10),
                      children: const [
                        TextSpan(
                          text: 'Atenção: ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: 'A extração da MIA pode conter erros.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              if (_enviando) _lendo(branco),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
        const Expanded(
          child: Text(
            'Digitalizar prescrição',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _fonte,
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _flash ? Icons.flash_on : Icons.flash_off,
            color: Colors.white,
          ),
          tooltip: _flash ? 'Desligar flash' : 'Ligar flash',
          onPressed: _camera == null ? null : _alternarFlash,
        ),
      ],
    );
  }

  Widget _areaDaFoto(TextStyle branco) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Posicione sua receita',
            style: branco.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text(
            'Enquadre todo o documento dentro da área indicada.',
            textAlign: TextAlign.center,
            style: branco.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: MolduraTracejada(
              child: ColoredBox(color: Colors.black, child: _conteudoDaMoldura()),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Evite sombras e mantenha o texto legível.',
            style: branco.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _conteudoDaMoldura() {
    final foto = _foto;
    if (foto != null) {
      if (foto.nome.toLowerCase().endsWith('.pdf')) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.white, size: 56),
              const SizedBox(height: 8),
              Text(foto.nome, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      }
      return Image.memory(
        foto.bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Text(
            'Não foi possível mostrar esta imagem.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final camera = _camera;
    if (camera != null && camera.value.isInitialized) {
      // Preenche a moldura cortando as sobras, como a câmera do celular.
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 100,
            height: 100 * camera.value.aspectRatio,
            child: CameraPreview(camera),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _semCamera == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _semCamera!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _fonte,
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _controlesCamera() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
          tooltip: 'Escolher foto ou PDF',
          iconSize: 28,
          onPressed: _escolherArquivo,
        ),
        // Botão de captura: anel branco com o centro na cor do app.
        Semantics(
          button: true,
          label: 'Tirar foto',
          child: GestureDetector(
            onTap: _camera == null ? _escolherArquivo : _fotografar,
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
              ),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.ciano,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
          tooltip: 'Trocar câmera',
          iconSize: 28,
          onPressed: _cameras.length > 1 ? _trocarCamera : null,
        ),
      ],
    );
  }

  Widget _controlesFoto() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _foto = null),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Tirar outra'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _usarFoto,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.darkCiano,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Usar esta foto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lendo(TextStyle branco) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'A MIA está lendo sua receita...',
                style: branco.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                'Isso pode levar até 1 minuto.',
                style: branco.copyWith(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '${_segundosLendo ~/ 60}:'
                '${(_segundosLendo % 60).toString().padLeft(2, '0')}',
                style: branco.copyWith(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
