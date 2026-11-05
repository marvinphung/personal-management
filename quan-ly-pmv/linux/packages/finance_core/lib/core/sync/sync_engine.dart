import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_database.dart';
import '../database/record.dart';

abstract class RemoteStore {
  Future<void> defaults();
  Future<bool> push(PendingOperation operation);
  Future<List<Record>> pull(Entity entity, int offset, int limit);
}

class SupabaseStore implements RemoteStore {
  final SupabaseClient client;
  final String userId;
  SupabaseStore(this.client, this.userId);
  void checkSession() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Session changed');
    }
  }

  @override
  Future<void> defaults() async {
    checkSession();
    await client.rpc('finance_defaults');
  }

  @override
  Future<bool> push(PendingOperation operation) async {
    checkSession();
    final result = await client.rpc(
      'finance_apply',
      params: {
        'operation_id': operation.id,
        'changes': operation.rows.map((r) => r.change).toList(),
      },
    );
    return result['conflict'] == true;
  }

  @override
  Future<List<Record>> pull(Entity entity, int offset, int limit) async {
    checkSession();
    final rows = await client
        .from(entity.table)
        .select()
        .eq('user_id', userId)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map((r) => Record(entity, r)).toList();
  }
}

class SyncEngine extends ChangeNotifier {
  final LocalDatabase db;
  final RemoteStore remote;
  bool busy = false, stopped = false;
  String? error;
  String? notice;
  Timer? timer;
  Future<void>? _flight;
  SyncEngine(this.db, this.remote);
  void start() {
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sync()),
    );
    unawaited(sync());
  }

  Future<void> sync() {
    if (stopped) return Future.value();
    return _flight ??= _run().whenComplete(() => _flight = null);
  }

  Future<void> _run() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await remote.defaults().timeout(const Duration(seconds: 20));
      if (stopped) return;
      var pushFailed = false;
      for (final op in await db.pending()) {
        if (stopped) return;
        try {
          final conflict = await remote
              .push(op)
              .timeout(const Duration(seconds: 20));
          if (stopped) return;
          if (conflict) {
            await db.reject(op);
          } else {
            await db.acknowledge(op.id);
          }
          if (conflict) {
            notice =
                'A change on another device won a conflict. Your data has been refreshed.';
            if (kDebugMode) debugPrint('sync conflict resolved: remote winner');
          }
        } catch (_) {
          if (!stopped) await db.failed(op.id);
          pushFailed = true;
        }
      }
      // Full paginated reconciliation avoids lost changes at timestamp/commit
      // boundaries. Pending local records are never overwritten by a pull.
      for (final entity in Entity.values) {
        var offset = 0;
        while (!stopped) {
          final page = await remote
              .pull(entity, offset, 250)
              .timeout(const Duration(seconds: 20));
          if (stopped) return;
          await db.mergeRemote(page);
          if (page.length < 250) break;
          offset += page.length;
        }
      }
      if (pushFailed) {
        error =
            "Some changes could not sync. Review the affected records or retry.";
      }
      if (!stopped && !pushFailed) {
        await db.setMetadata(
          'last_successful_sync',
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    } catch (_) {
      error =
          'Unable to sync. Changes are saved locally. Check your connection and session, then retry.';
      if (kDebugMode) debugPrint('sync failed; pending changes retained');
    } finally {
      busy = false;
      if (!stopped) notifyListeners();
    }
  }

  Future<void> stop() async {
    stopped = true;
    timer?.cancel();
    await _flight;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
