import 'package:api_client/api_client.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/app/router.dart';
import 'package:finance_core/features/auth/auth_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSessionStore implements SessionStore {
  String? _token;
  MockSessionStore([this._token]);

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

class TestAuthRepository extends AuthRepository {
  bool shouldThrowOnSignOut = false;
  int signOutCalls = 0;
  final UserDto mockUser;

  TestAuthRepository(super.client, {required this.mockUser});

  @override
  Future<UserDto> getCurrentUser() async => mockUser;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (shouldThrowOnSignOut) {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: 'Device is offline',
        statusCode: 503,
      );
    }
    await client.logout();
  }
}

class FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final activeUser = UserDto(
    id: 'user-uuid-1',
    username: 'pmv259',
    role: 'user',
    status: 'active',
    mustChangePassword: false,
    captureEnabled: true,
  );

  late MockSessionStore sessionStore;
  late TestAuthRepository authRepo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'language.user-uuid-1': 'vi',
      'language': 'vi',
    });
    prefs = await SharedPreferences.getInstance();
    sessionStore = MockSessionStore('valid-test-token');
    final dummyClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000/v1',
      sessionStore: sessionStore,
    );
    authRepo = TestAuthRepository(dummyClient, mockUser: activeUser);
  });

  test('Logout clears sessionStore and transitions sessionProvider to null', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        authRepositoryProvider.overrideWithValue(authRepo),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // Initial state: logged in
    final user = await container.read(sessionControllerProvider.future);
    expect(user, isNotNull);
    expect(user?.username, 'pmv259');
    expect(container.read(sessionProvider), isNotNull);

    // Call signOut
    await container.read(workspaceProvider.notifier).signOut();

    // Verify session state is synchronously and asynchronously null
    expect(container.read(sessionProvider), isNull);
    expect(await sessionStore.getToken(), isNull);
    expect(authRepo.signOutCalls, 1);
  });

  test('Logout is idempotent when called multiple times consecutively', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        authRepositoryProvider.overrideWithValue(authRepo),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    expect(container.read(sessionProvider), isNotNull);

    // Call signOut multiple times
    await container.read(workspaceProvider.notifier).signOut();
    await container.read(workspaceProvider.notifier).signOut();
    await container.read(workspaceProvider.notifier).signOut();

    expect(container.read(sessionProvider), isNull);
    expect(await sessionStore.getToken(), isNull);
  });

  test('Logout succeeds and clears session even when offline / server throws', () async {
    authRepo.shouldThrowOnSignOut = true;
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        authRepositoryProvider.overrideWithValue(authRepo),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    expect(container.read(sessionProvider), isNotNull);

    // Should not throw even when network/auth throws
    await expectLater(
      container.read(workspaceProvider.notifier).signOut(),
      completes,
    );

    expect(container.read(sessionProvider), isNull);
    expect(await sessionStore.getToken(), isNull);
  });

  test('Router redirects to /login for all routes when signed out and permits access when signed in', () async {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        authRepositoryProvider.overrideWithValue(authRepo),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionControllerProvider.future);
    final loggedInRouter = container.read(routerProvider);

    GoRouterState makeState(String path, GoRouter router) {
      final uri = Uri.parse(path);
      return GoRouterState(
        router.configuration,
        uri: uri,
        matchedLocation: path,
        fullPath: path,
        pathParameters: const {},
        pageKey: ValueKey(path),
      );
    }

    final fakeContext = FakeBuildContext();

    // 1. While logged in:
    // Root route is allowed (redirect returns null)
    expect(
      loggedInRouter.configuration.topRedirect(fakeContext, makeState('/', loggedInRouter)),
      isNull,
    );
    // Login route redirects to '/'
    expect(
      loggedInRouter.configuration.topRedirect(fakeContext, makeState('/login', loggedInRouter)),
      '/',
    );

    // 2. Perform sign out
    await container.read(workspaceProvider.notifier).signOut();

    // 3. While logged out:
    final loggedOutRouter = container.read(routerProvider);
    // Root route redirects to '/login'
    expect(
      loggedOutRouter.configuration.topRedirect(fakeContext, makeState('/', loggedOutRouter)),
      '/login',
    );
    // Protected routes redirect to '/login'
    expect(
      loggedOutRouter.configuration.topRedirect(fakeContext, makeState('/transactions', loggedOutRouter)),
      '/login',
    );
    expect(
      loggedOutRouter.configuration.topRedirect(fakeContext, makeState('/pending', loggedOutRouter)),
      '/login',
    );
    // Login route is allowed (redirect returns null)
    expect(
      loggedOutRouter.configuration.topRedirect(fakeContext, makeState('/login', loggedOutRouter)),
      isNull,
    );
  });
}
