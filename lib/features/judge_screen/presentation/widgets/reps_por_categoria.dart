import 'package:flutter/material.dart';
import '../../domain/models.dart';

/// Panel "Repeticiones por categoría" — equivalente al bloque de
/// JudgePage.tsx que muestra, por categoría activa, las reps/distancia de
/// la posición física del juez (cada categoría puede tener un número
/// distinto de reps en la misma base).
class RepsPorCategoriaPanel extends StatelessWidget {
  const RepsPorCategoriaPanel({super.key, required this.items});
  final List<RepsPorCategoria> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REPETICIONES POR CATEGORÍA',
              style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 2.6,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final cat = items[i];
              final color = _parseColor(cat.colorHex);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1815),
                  border: Border(
                    top: const BorderSide(color: Colors.white12),
                    right: const BorderSide(color: Colors.white12),
                    bottom: const BorderSide(color: Colors.white12),
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.nombre,
                        style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace', letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(cat.reps, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.white38;
    }
  }
}
