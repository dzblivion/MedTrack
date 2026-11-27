import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../compartilhamento/compartilhamento.dart';

/// "Dra. Ana quer acompanhar seu tratamento de Losartana → Ver".
class AvisoPedidos extends StatelessWidget {
  final List<PedidoDeAcesso> pedidos;
  final VoidCallback onVer;

  const AvisoPedidos({super.key, required this.pedidos, required this.onVer});

  @override
  Widget build(BuildContext context) {
    final primeiro = pedidos.first;
    final texto = pedidos.length == 1
        ? '${primeiro.profissional.nome} quer acompanhar seu tratamento de '
              '${primeiro.medicamento}.'
        : '${pedidos.length} profissionais pediram para acompanhar seus '
              'tratamentos.';

    return Material(
      color: AppColors.cianoClaro,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onVer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.darkCiano,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pedido de acesso',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.darkCiano,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      texto,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.inputText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Ver ›',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.darkCiano,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
