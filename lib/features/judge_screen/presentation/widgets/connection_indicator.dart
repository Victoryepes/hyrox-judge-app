import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/judge_providers.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(wsConnectedProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(connected ? Icons.wifi : Icons.wifi_off, size: 14, color: connected ? Colors.greenAccent : Colors.white38),
        const SizedBox(width: 4),
        Text(connected ? 'LIVE' : 'OFF',
            style: TextStyle(fontSize: 10, letterSpacing: 1, color: connected ? Colors.greenAccent : Colors.white38)),
      ],
    );
  }
}
