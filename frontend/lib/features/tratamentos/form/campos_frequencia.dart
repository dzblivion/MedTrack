import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_snackbar.dart';
import '../frequencia.dart';

TextStyle get _estiloRotulo => GoogleFonts.poppins(
      color: AppColors.inputText,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

Widget _erro(String texto) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        texto,
        style: GoogleFonts.poppins(color: AppColors.error, fontSize: 10),
      ),
    );

/// Horários das doses: cada um vira um botão (toque para trocar, "x" para
/// remover) e o "+" adiciona. Altera a lista [horarios] recebida.
class CampoHorarios extends StatelessWidget {
  final String rotulo;
  final List<String> horarios;

  /// Em intervalos só cabe 1 horário (o da primeira dose).
  final int? maximo;
  final VoidCallback onMudou;

  const CampoHorarios({
    super.key,
    required this.rotulo,
    required this.horarios,
    required this.onMudou,
    this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<void>(
      validator: (_) =>
          horarios.isEmpty ? 'Adicione pelo menos um horário' : null,
      builder: (campo) {
        final podeAdicionar = maximo == null || horarios.length < maximo!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: _estiloRotulo),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final horario in horarios)
                  _ChipHorario(
                    horario: horario,
                    onTrocar: () => _escolher(context, campo, trocar: horario),
                    onRemover: () => _mudar(campo, () => horarios.remove(horario)),
                  ),
                if (podeAdicionar)
                  Tooltip(
                    message: 'Adicionar horário',
                    child: Material(
                      color: AppColors.cianoClaro,
                      borderRadius: BorderRadius.circular(5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => _escolher(context, campo),
                        child: const SizedBox(
                          width: 48,
                          height: 28,
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: AppColors.darkCiano,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (campo.hasError) _erro(campo.errorText!),
          ],
        );
      },
    );
  }

  void _mudar(FormFieldState<void> campo, VoidCallback mudanca) {
    mudanca();
    onMudou();
    if (campo.hasError) campo.validate();
  }

  /// Abre o relógio para adicionar um horário ou [trocar] um existente.
  Future<void> _escolher(
    BuildContext context,
    FormFieldState<void> campo, {
    String? trocar,
  }) async {
    final escolhido = await showTimePicker(
      context: context,
      initialTime: _sugestao(trocar),
      helpText: 'Horário da dose',
    );
    if (escolhido == null) return;

    final texto = _formatar(escolhido);
    if (texto == trocar) return;
    if (horarios.contains(texto)) {
      if (context.mounted) {
        AppSnackBar.erro(context, 'Esse horário já foi adicionado.');
      }
      return;
    }

    _mudar(campo, () {
      if (trocar != null) horarios.remove(trocar);
      horarios
        ..add(texto)
        ..sort();
    });
  }

  /// O horário que está sendo trocado, ou 1 hora depois do último (08:00 se
  /// não houver nenhum).
  TimeOfDay _sugestao(String? trocar) {
    final base = trocar ?? (horarios.isEmpty ? null : horarios.last);
    if (base == null) return const TimeOfDay(hour: 8, minute: 0);
    final partes = base.split(':').map(int.parse).toList();
    if (trocar != null) return TimeOfDay(hour: partes[0], minute: partes[1]);
    return TimeOfDay(hour: (partes[0] + 1) % 24, minute: partes[1]);
  }

  static String _formatar(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')}';
}

class _ChipHorario extends StatelessWidget {
  final String horario;
  final VoidCallback onTrocar;
  final VoidCallback onRemover;

  const _ChipHorario({
    required this.horario,
    required this.onTrocar,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ciano,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTrocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                horario,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Tooltip(
                message: 'Remover $horario',
                child: InkWell(
                  onTap: onRemover,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dias da semana da frequência semanal. Altera o conjunto [dias] recebido.
class CampoDiasSemana extends StatelessWidget {
  final Set<int> dias;
  final VoidCallback onMudou;

  const CampoDiasSemana({
    super.key,
    required this.dias,
    required this.onMudou,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<void>(
      validator: (_) => dias.isEmpty ? 'Escolha pelo menos um dia' : null,
      builder: (campo) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dias da semana*', style: _estiloRotulo),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: dia, value: nome) in diasDaSemana.entries)
                _ChipDia(
                  nome: nome,
                  marcado: dias.contains(dia),
                  onTap: () {
                    if (!dias.remove(dia)) dias.add(dia);
                    onMudou();
                    if (campo.hasError) campo.validate();
                  },
                ),
            ],
          ),
          if (campo.hasError) _erro(campo.errorText!),
        ],
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  final String nome;
  final bool marcado;
  final VoidCallback onTap;

  const _ChipDia({
    required this.nome,
    required this.marcado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: marcado ? AppColors.ciano : AppColors.field,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 28,
          child: Center(
            child: Text(
              nome,
              style: GoogleFonts.poppins(
                color: marcado ? Colors.white : AppColors.gray,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
