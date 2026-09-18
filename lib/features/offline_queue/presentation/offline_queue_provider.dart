import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../judge_screen/presentation/providers/judge_providers.dart';
import '../domain/pending_action.dart';
import '../service/offline_queue_service.dart';

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService(ref.watch(timingApiProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Lista en vivo de acciones aún sin confirmar (pendientes, reintentando o
/// definitivamente fallidas) — antes esto vivía solo en la BD local sin
/// ninguna pantalla que lo mostrara, así que una acción que agotaba sus
/// reintentos desaparecía en silencio desde el punto de vista del juez.
class PendingActionsNotifier extends StateNotifier<List<PendingAction>> {
  PendingActionsNotifier(this._ref) : super([]) {
    _sub = _ref.read(offlineQueueProvider).onActionResolved.listen((_) => refresh());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    refresh();
  }

  final Ref _ref;
  StreamSubscription? _sub;
  Timer? _timer;

  Future<void> refresh() async {
    state = await _ref.read(offlineQueueProvider).pendientes();
  }

  Future<void> descartar(String id) async {
    await _ref.read(offlineQueueProvider).descartar(id);
    await refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final pendingActionsProvider =
    StateNotifierProvider<PendingActionsNotifier, List<PendingAction>>((ref) => PendingActionsNotifier(ref));
