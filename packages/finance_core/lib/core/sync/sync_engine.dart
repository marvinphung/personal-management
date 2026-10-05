import 'dart:async';
import 'package:api_client/api_client.dart';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import 'outbox.dart';

class SyncEngine extends ChangeNotifier {
  final LocalDatabase db;
  final ApiClient apiClient;
  final RealtimeClient? realtimeClient;
  final OutboxStore outbox;
  bool busy = false, stopped = false;
  String? error;
  String? notice;
  Timer? timer;
  StreamSubscription<InboxSnapshotEvent>? _realtimeSub;
  StreamSubscription<SyncRequiredEvent>? _syncReqSub;
  Future<void>? _flight;

  SyncEngine(
    this.db,
    this.apiClient, {
    this.realtimeClient,
  }) : outbox = OutboxStore(db);

  void start() {
    timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(sync()),
    );
    unawaited(sync());

    if (realtimeClient != null) {
      unawaited(realtimeClient!.connect());
      _realtimeSub = realtimeClient!.inboxSnapshots.listen((snapshot) async {
        final rawEvents = snapshot.events
            .map((e) => {
                  'id': e.id,
                  'user_id': e.userId,
                  'binding_id': e.bindingId,
                  'bank_code': e.bankCode,
                  'owner_account_snapshot': e.ownerAccountSnapshot,
                  'amount_vnd': e.amountVnd.toString(),
                  'direction': e.direction,
                  'occurred_at': e.occurredAt,
                  'time_source': e.timeSource,
                  'received_at': e.receivedAt,
                  'bank_description': e.bankDescription,
                  'version': e.version,
                })
            .toList();
        await db.applyInboxSnapshot(snapshot.inboxRevision, rawEvents);
        notifyListeners();
      });

      _syncReqSub = realtimeClient!.syncRequiredEvents.listen((_) {
        unawaited(sync());
      });
    }
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
      // 1. Drain outbox if any operations exist
      final pendingOps = await outbox.getPending();
      if (pendingOps.isNotEmpty) {
        final payloadList = pendingOps.map((op) => op.toJson()).toList();
        final results = await apiClient.postOperations(payloadList);

        for (final res in results) {
          final opId = res['operation_id'] as String;
          final status = res['status'] as String;

          if (status == 'success') {
            // Check if canonical ID was resolved
            if (res['outcome_code'] == 'canonical_resolved' && res['canonical_id'] != null) {
              final canonicalId = res['canonical_id'] as String;
              final op = pendingOps.firstWhere((p) => p.id == opId);
              final clientProposedId = op.payload['id'] as String?;
              if (clientProposedId != null && clientProposedId != canonicalId) {
                await outbox.remapId(clientProposedId, canonicalId);
              }
            }
            await outbox.remove(opId);
          } else if (status == 'conflict') {
            notice = 'Xung đột phiên bản dữ liệu. Dữ liệu máy chủ được ưu tiên.';
            await outbox.remove(opId);
          } else {
            final errMsg = res['message'] as String? ?? 'Thao tác không thành công';
            await outbox.markError(opId, errMsg);
          }
        }
      }

      if (stopped) return;

      // 2. Fetch snapshot with known revision
      final revStr = await db.metadata('revision');
      final knownRev = revStr != null ? int.tryParse(revStr) : null;

      final snapshotResp = await apiClient.getSnapshot(knownRevision: knownRev);
      if (stopped) return;

      if (snapshotResp['status'] == 'snapshot') {
        await db.applySnapshot(snapshotResp);
        await db.setMetadata(
          'last_successful_sync',
          DateTime.now().toUtc().toIso8601String(),
        );
      } else if (snapshotResp['status'] == 'unchanged') {
        await db.setMetadata(
          'last_successful_sync',
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    } on ApiException catch (e) {
      error = e.message;
      if (kDebugMode) debugPrint('SyncEngine ApiException: ${e.message}');
    } catch (e) {
      error = 'Không thể đồng bộ. Dữ liệu đã được lưu ngoại tuyến.';
      if (kDebugMode) debugPrint('SyncEngine error: $e');
    } finally {
      busy = false;
      if (!stopped) notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (stopped) return;
    try {
      super.notifyListeners();
    } catch (_) {}
  }

  Future<void> stop() async {
    stopped = true;
    timer?.cancel();
    _realtimeSub?.cancel();
    _syncReqSub?.cancel();
    realtimeClient?.disconnect();
    await _flight;
  }

  @override
  void dispose() {
    stopped = true;
    timer?.cancel();
    _realtimeSub?.cancel();
    _syncReqSub?.cancel();
    realtimeClient?.disconnect();
    super.dispose();
  }
}
