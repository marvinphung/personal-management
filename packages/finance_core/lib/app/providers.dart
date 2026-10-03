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

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final currentUserProvider = FutureProvider<UserDto?>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  final token = await ref.watch(sessionStoreProvider).getToken();
  if (token == null) return null;
  try {
    return await auth.getCurrentUser();
  } catch (_) {
    return null;
  }
});

final sessionProvider = Provider<UserDto?>((ref) {
  return ref.watch(currentUserProvider).value;
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
            sync = SyncEngine(db, apiClient);
        _current = UserWorkspace(db, repository, sync);
        sync.start();
        return _current;

      } catch (_) {
        await db.close();
        rethrow;
      }
    });
  }

  Future<void> signOut() async {
    ++_generation;
    await _lifecycle.synchronized(() async {
      await ref.read(bankDraftRepositoryProvider).setOwner(null);
      final current = _current;
      _current = null;
      if (current != null) await current.close(clear: true);
    });
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(currentUserProvider);
    ref.invalidateSelf();
  }
}

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


