import 'package:flutter_test/flutter_test.dart';
import 'package:api_client/api_client.dart';
import 'package:finance_core/features/auth/auth_repository.dart';

void main() {
  group('Mobile Auth Repository Tests', () {
    test('AuthRepository methods delegate properly to ApiClient', () async {
      final sessionStore = InMemorySessionStore();
      // Using mock-like implementation with in-memory session store
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
      );
      final repo = AuthRepository(api);
      expect(repo.client, equals(api));
    });

    test('SessionStore saves, reads, and clears token', () async {
      final store = InMemorySessionStore();
      expect(await store.getToken(), isNull);

      await store.saveToken('token_xyz');
      expect(await store.getToken(), 'token_xyz');

      await store.clear();
      expect(await store.getToken(), isNull);
    });
  });
}
