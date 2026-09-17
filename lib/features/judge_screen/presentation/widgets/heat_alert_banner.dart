import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/judge_providers.dart';

class HeatAlertBanner extends ConsumerWidget {
  const HeatAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerta = ref.watch(alertaHeatProvider);
    if (alerta == null) return const SizedBox.shrink();

    final restante = alerta.minutosRestantes;
    final label = restante > 0
        ? 'Inicia en $restante min'
        : restante == 0
            ? 'Iniciando ahora'
            : 'Ola retrasada ${restante.abs()} min';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alerta.nombreHeat,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                onPressed: () => ref.read(alertaHeatProvider.notifier).state = null,
              ),
            ],
          ),
          Text('$label · ${alerta.totalCompetidores} atletas',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (alerta.competidores.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: alerta.competidores
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                        child: Text('#${c.numeroDorsal} ${c.nombre}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
