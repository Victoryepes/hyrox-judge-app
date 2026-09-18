import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../offline_queue/domain/pending_action.dart';
import '../../../offline_queue/presentation/offline_queue_provider.dart';

const _labelTipo = {
  ActionType.marcarDorsal: 'Marcar dorsal',
  ActionType.registrarSalida: 'Registrar salida',
  ActionType.penalizacionCatalogo: 'Penalización',
  ActionType.penalizacionLibre: 'Penalización',
};

/// Antes, una acción que agotaba sus reintentos de sincronización
/// desaparecía en silencio — el juez nunca se enteraba de que ese dato se
/// perdió. Este ícono muestra cuántas acciones siguen pendientes/fallidas
/// y permite verlas (y descartar las fallidas) con un toque.
class OfflineQueueIndicator extends ConsumerWidget {
  const OfflineQueueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acciones = ref.watch(pendingActionsProvider);
    if (acciones.isEmpty) return const SizedBox.shrink();

    final fallidas = acciones.where((a) => a.status == ActionStatus.failed).length;
    final color = fallidas > 0 ? Colors.redAccent : Colors.amberAccent;

    return InkWell(
      onTap: () => _mostrarDetalle(context, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fallidas > 0 ? Icons.error_outline : Icons.sync_problem, size: 14, color: color),
          const SizedBox(width: 4),
          Text('${acciones.length}', style: TextStyle(fontSize: 10, letterSpacing: 1, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1815),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final acciones = ref.watch(pendingActionsProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Acciones sin sincronizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (acciones.isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 24), child: Text('Todo sincronizado', style: TextStyle(color: Colors.white54))),
                ...acciones.map((a) => _FilaAccion(accion: a)),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaAccion extends ConsumerWidget {
  const _FilaAccion({required this.accion});
  final PendingAction accion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallida = accion.status == ActionStatus.failed;
    final dorsal = accion.payload['numeroDorsal'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: fallida ? Colors.red.shade900 : Colors.white24),
      ),
      child: Row(
        children: [
          Icon(fallida ? Icons.error : Icons.hourglass_top, size: 18, color: fallida ? Colors.redAccent : Colors.amberAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_labelTipo[accion.actionType] ?? accion.actionType.name}${dorsal != null ? ' — dorsal $dorsal' : ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  fallida
                      ? 'No se pudo sincronizar tras ${accion.attempts} intentos — este dato se perdió.'
                      : 'Reintentando... (${accion.attempts} intento${accion.attempts == 1 ? '' : 's'})',
                  style: TextStyle(color: fallida ? Colors.redAccent : Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          if (fallida)
            TextButton(
              onPressed: () => ref.read(pendingActionsProvider.notifier).descartar(accion.id),
              child: const Text('Descartar', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
