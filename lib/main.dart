import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/access_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/judge_screen/presentation/judge_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: HyroxJudgeApp()));
}

class HyroxJudgeApp extends StatelessWidget {
  const HyroxJudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyrox Judge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF14100E),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent, brightness: Brightness.dark),
      ),
      home: const _RootRouter(),
    );
  }
}

/// Equivalente al enrutamiento de App.tsx (`/` → landing/acceso, `/juez` → JudgePage
/// protegida) pero simplificado: esta app solo tiene el flujo del juez.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const AccessScreen(),
      data: (session) => session == null ? const AccessScreen() : const JudgeHomeScreen(),
    );
  }
}
