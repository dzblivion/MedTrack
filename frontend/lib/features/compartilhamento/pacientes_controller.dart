import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import 'compartilhamento.dart';
import 'compartilhamento_repository.dart';

/// Um paciente e os tratamentos que ele compartilhou com o profissional.
typedef PacienteComTratamentos = ({
  String nome,
  List<TratamentoDePaciente> tratamentos,
});

/// Aba "Pacientes" do profissional.
class PacientesController extends ChangeNotifier {
  final CompartilhamentoRepository _repositorio;

  List<TratamentoDePaciente> _tratamentos = const [];
  bool _carregando = false;
  String? _erro;
  bool _descartado = false;

  PacientesController(this._repositorio);

  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get vazio => _tratamentos.isEmpty;

  /// Agrupados por paciente, em ordem alfabética.
  List<PacienteComTratamentos> get pacientes {
    final porPaciente = <int, List<TratamentoDePaciente>>{};
    for (final t in _tratamentos) {
      porPaciente.putIfAbsent(t.pacienteId, () => []).add(t);
    }
    return [
      for (final lista in porPaciente.values)
        (nome: lista.first.pacienteNome, tratamentos: lista),
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();
    try {
      _tratamentos = await _repositorio.listarDoProfissional();
    } on ApiException catch (e) {
      _erro = e.mensagem;
    } catch (_) {
      _erro = 'Não foi possível carregar seus pacientes.';
    }
    _carregando = false;
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
