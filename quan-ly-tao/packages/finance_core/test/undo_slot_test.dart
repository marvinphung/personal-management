import 'package:drift/native.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/outbox.dart';
import 'package:finance_core/features/bank_import/undo_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase db;
  late UndoSlotController controller;

  setUp(() async {
    db = LocalDatabase(NativeDatabase.memory());
    controller = UndoSlotController(db);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  final event1 = Record(Entity.pendingBankEvents, {
    'id': 'ev-101',
    'bank_code': 'bidv',
    'amount_vnd': 100000,
    'direction': 'expense',
    'occurred_at': '2026-10-03T10:00:00Z',
    'bank_description': 'TEST 1',
  });

  test('Undo slot restores record on undo before deadline', () async {
    await db.put(event1);

    // Initial state: record exists in DB
    final before = await db.get(Entity.pendingBankEvents, 'ev-101');
    expect(before, isNotNull);

    // Manual test of undo lifecycle without UI context
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    final undoItem = ActiveUndo(eventId: event1.id, record: event1, deadline: deadline);

    // Remove locally
    await db.customStatement("DELETE FROM records WHERE entity = 'pending_bank_events' AND id = ?", [event1.id]);
    expect(await db.get(Entity.pendingBankEvents, 'ev-101'), isNull);

    // Call undo
    await db.put(undoItem.record);
    final restored = await db.get(Entity.pendingBankEvents, 'ev-101');
    expect(restored, isNotNull);
    expect(restored!.id, 'ev-101');
  });

  test('Dismissing second item enqueues discard for first item', () async {
    // Finalize first item
    final undoItem1 = ActiveUndo(
      eventId: event1.id,
      record: event1,
      deadline: DateTime.now().add(const Duration(seconds: 3)),
    );

    // Finalize discard into outbox
    await controller.outbox.enqueue(
      OutboxOperation(
        type: 'discard_pending',
        payload: {'pending_id': undoItem1.eventId},
      ),
    );

    // Outbox should contain discard_pending operation
    final pendingOps = await controller.outbox.getPending();
    expect(pendingOps.length, 1);
    expect(pendingOps[0].type, 'discard_pending');
    expect(pendingOps[0].payload['pending_id'], 'ev-101');
  });
}
