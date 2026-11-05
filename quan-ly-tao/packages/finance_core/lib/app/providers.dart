import '../features/bank_import/bank_draft_repository.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../core/database/local_database.dart';
import '../core/database/finance_repository.dart';
import '../core/database/record.dart';
import '../core/database/search_repository.dart';
import '../core/sync/sync_engine.dart';
import '../features/auth/auth_repository.dart';
import 'widget_bridge.dart';

import 'package:api_client/api_client.dart';
import '../features/auth/secure_session_storage.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStorage();
});

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/v1');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  return RealtimeClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

enum AuthLifecycleState {
  restoring,
  authenticated,
  signingOut,
  signedOut,
}

class SessionState {
  final AuthLifecycleState lifecycle;
  final UserDto? user;
  final int generation;

  const SessionState({
    required this.lifecycle,
    this.user,
    required this.generation,
  });

  bool get isAuthenticated => lifecycle == AuthLifecycleState.authenticated && user != null;
  bool get isSigningOut => lifecycle == AuthLifecycleState.signingOut;
  bool get isRestoring => lifecycle == AuthLifecycleState.restoring;
  bool get isSignedOut => lifecycle == AuthLifecycleState.signedOut;
}

class SessionController extends AsyncNotifier<SessionState> {
  int _generation = 0;

  @override
  Future<SessionState> build() async {
    final generation = ++_generation;
    final auth = ref.watch(authRepositoryProvider);
    final token = await ref.watch(sessionStoreProvider).getToken();
    if (token == null || token.isEmpty) {
      return SessionState(
        lifecycle: AuthLifecycleState.signedOut,
        generation: generation,
      );
    }
    try {
      final user = await auth.getCurrentUser();
      if (generation != _generation) {
        return SessionState(
          lifecycle: AuthLifecycleState.signedOut,
          generation: generation,
        );
      }
      return SessionState(
        lifecycle: AuthLifecycleState.authenticated,
        user: user,
        generation: generation,
      );
    } catch (_) {
      return SessionState(
        lifecycle: AuthLifecycleState.signedOut,
        generation: generation,
      );
    }
  }

  void setAuthenticated(UserDto user) {
    final generation = ++_generation;
    state = AsyncData(SessionState(
      lifecycle: AuthLifecycleState.authenticated,
      user: user,
      generation: generation,
    ));
  }

  void startSignOut() {
    final generation = ++_generation;
    state = AsyncData(SessionState(
      lifecycle: AuthLifecycleState.signingOut,
      user: null,
      generation: generation,
    ));
  }

  void completeSignOut() {
    state = AsyncData(SessionState(
      lifecycle: AuthLifecycleState.signedOut,
      user: null,
      generation: _generation,
    ));
  }

  void setSignedOut() {
    startSignOut();
    completeSignOut();
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

final sessionStateProvider = Provider<SessionState>((ref) {
  return ref.watch(sessionControllerProvider).value ??
      const SessionState(
        lifecycle: AuthLifecycleState.restoring,
        user: null,
        generation: 0,
      );
});

final currentUserProvider = FutureProvider<UserDto?>((ref) async {
  final session = await ref.watch(sessionControllerProvider.future);
  return session.user;
});

final sessionProvider = Provider<UserDto?>((ref) {
  return ref.watch(sessionControllerProvider).value?.user;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider)?.id;
});
final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'Preferences must be initialized before starting the app',
  ),
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values[ref.read(preferencesProvider).getInt('theme') ?? 0];
  Future<void> set(ThemeMode value) async {
    state = value;
    await ref.read(preferencesProvider).setInt('theme', value.index);
  }
}

final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class CurrencyController extends Notifier<String> {
  @override
  String build() =>
      ref.read(preferencesProvider).getString('currency') ?? 'VND';
  Future<void> set(String value) async {
    state = value;
    await ref.read(preferencesProvider).setString('currency', value);
  }
}

final currencyProvider = NotifierProvider<CurrencyController, String>(
  CurrencyController.new,
);

class UserWorkspace {
  final LocalDatabase db;
  final FinanceRepository repository;
  final SyncEngine sync;
  UserWorkspace(this.db, this.repository, this.sync);
  Future<void> close({bool clear = false}) async {
    await sync.stop();
    if (clear) await db.clearPrivate();
    await db.close();
    sync.dispose();
  }
}

/// A single lifecycle owner serializes cache teardown against opening another user.
class WorkspaceController extends AsyncNotifier<UserWorkspace?> {
  UserWorkspace? _current;
  final Lock _lifecycle = Lock();
  int _generation = 0;
  @override
  Future<UserWorkspace?> build() {
    final user = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    final apiClient = ref.read(apiClientProvider);
    return _lifecycle.synchronized(() async {
      if (generation != _generation) return null;
      if (_current?.repository.userId == user) {
        await ref.read(bankDraftRepositoryProvider).setOwner(user);
        return _current;
      }
      if (_current != null) {
        await _current!.close(clear: true);
        _current = null;
      }
      await ref.read(bankDraftRepositoryProvider).setOwner(user);
      if (user == null) return null;
      if (BankDraftRepository.supported) {
        await ref.read(bankDraftRepositoryProvider).configure({
          'language':
              ref.read(preferencesProvider).getString('language.$user') ?? 'en',
        });
      }
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final db = LocalDatabase.file(
        File(path.join(directory.path, 'finance_$user.sqlite')),
      );
      try {
        final owner = await db.metadata('owner');
        if (owner != user) await db.clearPrivate();
        await db.setMetadata('owner', user);
        if (generation != _generation) {
          await db.clearPrivate();
          await db.close();
          return null;
        }
        final repository = FinanceRepository(db, user),
            realtimeClient = ref.read(realtimeClientProvider),
            sync = SyncEngine(db, apiClient, realtimeClient: realtimeClient);
        _current = UserWorkspace(db, repository, sync);
        sync.start();
        unawaited(() async {
          try {
            final widgetTokenDto = await apiClient.createWidgetToken();
            if (generation != _generation) return;
            final baseUrl = ref.read(apiBaseUrlProvider);
            await UserWidgetBridge.setWidgetCredentials(
              token: widgetTokenDto.token,
              baseUrl: baseUrl,
              owner: user,
              generation: generation,
            );
          } catch (e) {
            debugPrint('Failed to acquire scoped widget token: $e');
          }
        }());
        return _current;

      } catch (error, stackTrace) {
        debugPrint('Failed to open local workspace: $error');
        debugPrintStack(stackTrace: stackTrace);
        await db.close();
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    final generation = ++_generation;
    final capturedToken = await ref.read(sessionStoreProvider).getToken();
    ref.read(sessionControllerProvider.notifier).startSignOut();

    try {
      try {
        await UserWidgetBridge.clearWidget();
      } catch (_) {}

      try {
        await ref.read(bankDraftRepositoryProvider).setOwner(null);
      } catch (_) {}

      await _lifecycle.synchronized(() async {
        final current = _current;
        _current = null;
        if (current != null) await current.close(clear: true);
      });

      try {
        await ref.read(authRepositoryProvider).signOut(tokenToRevoke: capturedToken).timeout(
          const Duration(seconds: 4),
          onTimeout: () => debugPrint('Server signOut timed out'),
        );
      } catch (e) {
        debugPrint('Auth signOut error: $e');
      }
    } finally {
      try {
        final currentToken = await ref.read(sessionStoreProvider).getToken();
        if (currentToken == capturedToken || currentToken == null) {
          await ref.read(sessionStoreProvider).clear();
        }
      } catch (e) {
        debugPrint('Failed to clear session store: $e');
      }

      ref.read(sessionControllerProvider.notifier).completeSignOut();

      if (generation == _generation) {
        ref.invalidate(currentUserProvider);
        ref.invalidate(pendingProvider);
        ref.invalidate(balanceProvider);
        ref.invalidateSelf();
      }
    }
  }
}

final hasUnsyncedChangesProvider = FutureProvider<bool>((ref) async {
  final state = ref.watch(workspaceProvider);
  final ws = state.value;
  if (ws == null) return false;
  final cnt = await ws.db.pendingOutboxCount();
  return cnt > 0;
});

final workspaceProvider =
    AsyncNotifierProvider<WorkspaceController, UserWorkspace?>(
      WorkspaceController.new,
    );
final databaseEventsProvider = StreamProvider<int>((ref) {
  final state = ref.watch(workspaceProvider);
  final workspace = state.isLoading ? null : state.value;
  // Riverpod suppresses equal stream values. Each committed change needs a
  // distinct revision so repeated void/null database events refresh readers.
  var revision = 0;
  return workspace?.db.changes.stream.map((_) => ++revision) ??
      const Stream<int>.empty();
});
final recordsProvider = FutureProvider.family<List<Record>, Entity>((
  ref,
  entity,
) async {
  ref.watch(databaseEventsProvider);
  final workspace = await ref.watch(workspaceProvider.future);
  if (workspace == null) return [];
  return workspace.db.list(
    entity,
    limit: entity == Entity.transactions ? 100 : null,
  );
});
final calendarTickProvider = StreamProvider<int>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (i) => i),
);
final balanceProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(databaseEventsProvider);
  ref.watch(calendarTickProvider);
  final w = await ref.watch(workspaceProvider.future);
  return await w?.db.balances() ?? {};
});
final pendingProvider = FutureProvider<List<PendingOperation>>((ref) async {
  ref.watch(databaseEventsProvider);
  final w = await ref.watch(workspaceProvider.future);
  return await w?.db.pending() ?? [];
});

class MonthController extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime(DateTime.now().year, DateTime.now().month);
  void move(int delta) => state = DateTime(state.year, state.month + delta);
}

final monthProvider = NotifierProvider<MonthController, DateTime>(
  MonthController.new,
);
final monthTransactionsProvider = FutureProvider<List<Record>>((ref) async {
  ref.watch(databaseEventsProvider);
  ref.watch(calendarTickProvider);
  final month = ref.watch(monthProvider);
  final w = await ref.watch(workspaceProvider.future);
  return await w?.db.list(Entity.transactions, month: month) ?? [];
});
Future<void> saveAndSync(
  WidgetRef ref,
  Future<void> Function(FinanceRepository) action,
) async {
  final workspace = await ref.read(workspaceProvider.future);
  if (workspace == null) throw const FormatException('Please sign in again');
  await action(workspace.repository);
  unawaited(workspace.sync.sync());
}

final searchRepositoryProvider = FutureProvider<SearchRepository?>((ref) async {
  final w = await ref.watch(workspaceProvider.future);
  return w == null ? null : SearchRepository(w.db);
});

