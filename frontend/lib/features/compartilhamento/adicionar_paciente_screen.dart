import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_text_field.dart';
import 'compartilhamento_repository.dart';

/// O profissional cola o código que o paciente gerou. Vira um pedido que
/// o paciente precisa aprovar.
class AdicionarPacienteScreen extends StatefulWidget {
  const AdicionarPacienteScreen({super.key});

  @override
  State<AdicionarPacienteScreen> createState() =>
      _AdicionarPacienteScreenState();
}

class _AdicionarPacienteScreenState extends State<AdicionarPacienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _colar() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = dados?.text?.trim();
    if (texto == null || texto.isEmpty) return;
    _codigo.text = texto;
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await context.read<CompartilhamentoRepository>().usarCodigo(_codigo.text);
      if (!mounted) return;
      setState(() => _enviando = false);
      await showDialog<void>(
        context: context,
        builder: (contexto) => AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.ciano,
            size: 40,
          ),
          title: const Text('Pedido enviado!'),
          content: const Text(
            'Agora o paciente precisa aprovar o acesso no app dele. '
            'Depois disso, o tratamento aparece em "Meus pacientes".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexto).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) AppSnackBar.erro(context, e.mensagem);
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(context, 'Algo deu errado. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.darkCiano,
        elevation: 0,
        title: const Text(
          'Adicionar paciente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const Text(
                'Peça ao paciente para abrir o tratamento no MedTrack e tocar '
                'em "Compartilhar com profissional". Ele vai te enviar um '
                'código; cole aqui.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.gray,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Código de compartilhamento',
                hint: 'Cole o código aqui',
                controller: _codigo,
                textInputAction: TextInputAction.done,
                validator: (valor) =>
                    (valor ?? '').trim().isEmpty ? 'Informe o código.' : null,
                onFieldSubmitted: (_) => _enviar(),
                suffixIcon: IconButton(
                  tooltip: 'Colar',
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    size: 18,
                    color: AppColors.darkCiano,
                  ),
                  onPressed: _colar,
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                texto: 'Enviar pedido',
                carregando: _enviando,
                onPressed: _enviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
