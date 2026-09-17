import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hyrox_judge/core/storage/secure_session.dart';
import 'package:hyrox_judge/features/auth/presentation/providers/auth_provider.dart';
import 'package:hyrox_judge/main.dart';

/// flutter_secure_storage usa platform channels que no existen en el entorno
/// de test — se reemplaza por un stub que resuelve "sin sesión" de inmediato.
class _FakeSecureSessionStore extends SecureSessionStore {
  @override
  Future<JuezSession?> load() async => null;
}

void main() {
  testWidgets('App arranca y muestra la pantalla de acceso', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [secureSessionStoreProvider.overrideWithValue(_FakeSecureSessionStore())],
      child: const HyroxJudgeApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('HYROX JUDGE'), findsOneWidget);
  });
}
