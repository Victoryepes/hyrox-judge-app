import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../judge_screen/presentation/providers/judge_providers.dart';
import '../service/offline_queue_service.dart';

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService(ref.watch(timingApiProvider));
  ref.onDispose(service.dispose);
  return service;
});
