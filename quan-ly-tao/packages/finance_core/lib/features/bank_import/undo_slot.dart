import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../app/providers.dart';
import '../../core/database/local_database.dart';
import '../../core/database/record.dart';
import '../../core/sync/outbox.dart';

class ActiveUndo {
  final String eventId;
  final Record record;
  final DateTime deadline;

  ActiveUndo({
    required this.eventId,
    required this.record,
    required this.deadline,
  });

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'record': record.data,
        'deadline': deadline.toUtc().toIso8601String(),
      };

  factory ActiveUndo.fromJson(Map<String, dynamic> json) => ActiveUndo(
        eventId: json['event_id'] as String,
        record: Record(Entity.pendingBankEvents, json['record'] as Map<String, dynamic>),
        deadline: DateTime.parse(json['deadline'] as String).toLocal(),
      );
}

class UndoSlotController extends ChangeNotifier {
  final LocalDatabase db;
  final OutboxStore outbox;
  ActiveUndo? _active;
  Timer? _timer;

  UndoSlotController(this.db) : outbox = OutboxStore(db) {
    _recoverFromStorage();
  }

  ActiveUndo? get active => _active;
  bool get hasActive => _active != null;

  Future<void> _recoverFromStorage() async {
    final raw = await db.metadata('active_undo_slot');
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final recovered = ActiveUndo.fromJson(decoded);

      if (DateTime.now().isAfter(recovered.deadline)) {
        // Deadline passed while app was closed -> finalize discard immediately
        await _finalizeDiscard(recovered);
        await db.setMetadata('active_undo_slot', '');
      } else {
        // Still within deadline window -> start timer for remaining duration
        _active = recovered;
        notifyListeners();
        final remaining = recovered.deadline.difference(DateTime.now());
        _timer = Timer(remaining, () => _onDeadlineExpired(recovered));
      }
    } catch (_) {
      await db.setMetadata('active_undo_slot', '');
    }
  }

  Future<void> dismiss(
    BuildContext context,
    Record event, {
    VoidCallback? onStateChanged,
  }) async {
    // 1. If another item is already in undo slot, finalize it first
    if (_active != null) {
      _timer?.cancel();
      await _finalizeDiscard(_active!);
    }

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    final undoItem = ActiveUndo(
      eventId: event.id,
      record: event,
      deadline: deadline,
    );

    _active = undoItem;
    notifyListeners();

    // 2. Persist to storage before hiding from UI
    await db.setMetadata('active_undo_slot', jsonEncode(undoItem.toJson()));

    // 3. Hide locally from pending records
    await db.customStatement(
      "DELETE FROM records WHERE entity = 'pending_bank_events' AND id = ?",
      [event.id],
    );
    onStateChanged?.call();

    // 4. Start 3-second timer
    _timer = Timer(const Duration(seconds: 3), () => _onDeadlineExpired(undoItem));

    // 5. Show durable single SnackBar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã bỏ qua biến động'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: Colors.amber,
            onPressed: () => undo(onStateChanged: onStateChanged),
          ),
        ),
      );
    }
  }

  Future<void> undo({VoidCallback? onStateChanged}) async {
    if (_active == null) return;

    _timer?.cancel();
    final item = _active!;
    _active = null;
    notifyListeners();

    // Clear persisted slot
    await db.setMetadata('active_undo_slot', '');

    // Restore record locally
    await db.put(item.record);
    onStateChanged?.call();
  }

  Future<void> _onDeadlineExpired(ActiveUndo item) async {
    if (_active?.eventId != item.eventId) return;

    _active = null;
    notifyListeners();

    await _finalizeDiscard(item);
    await db.setMetadata('active_undo_slot', '');
  }

  Future<void> _finalizeDiscard(ActiveUndo item) async {
    final opId = const Uuid().v4();
    await outbox.enqueue(
      OutboxOperation(
        id: opId,
        type: 'discard_pending',
        payload: {'pending_id': item.eventId},
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final undoSlotControllerProvider = ChangeNotifierProvider<UndoSlotController?>((ref) {
  final workspace = ref.watch(workspaceProvider).value;
  if (workspace == null) return null;
  return UndoSlotController(workspace.db);
});
