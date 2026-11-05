import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../database/local_database.dart';

class OutboxOperation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final String? error;
  final int? sequence;

  OutboxOperation({
    String? id,
    required this.type,
    required this.payload,
    this.error,
    this.sequence,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'operation_id': id,
        'type': type,
        'payload': payload,
      };

  factory OutboxOperation.fromRow(int sequence, String id, String rawPayload, String? error) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is List) {
      return OutboxOperation(
        id: id,
        type: 'batch_save',
        payload: {'rows': decoded},
        error: error,
        sequence: sequence,
      );
    }
    final map = decoded as Map<String, dynamic>;
    return OutboxOperation(
      id: id,
      type: (map['type'] as String?) ?? 'custom',
      payload: (map['payload'] as Map<String, dynamic>?) ?? map,
      error: error,
      sequence: sequence,
    );
  }
}

class OutboxStore {
  final LocalDatabase db;
  OutboxStore(this.db);

  Future<void> enqueue(OutboxOperation op) async {
    final payloadJson = jsonEncode({'type': op.type, 'payload': op.payload});
    await db.customStatement(
      'INSERT INTO outbox (id, payload, error) VALUES (?, ?, ?)',
      [op.id, payloadJson, op.error],
    );
    db.changes.add(null);
  }

  Future<List<OutboxOperation>> getPending() async {
    final rows = await db.customSelect(
      'SELECT sequence, id, payload, error FROM outbox ORDER BY sequence ASC',
    ).get();
    return rows.map((r) => OutboxOperation.fromRow(
          r.read<int>('sequence'),
          r.read<String>('id'),
          r.read<String>('payload'),
          r.readNullable<String>('error'),
        )).toList();
  }

  Future<void> remove(String id) async {
    await db.customStatement('DELETE FROM outbox WHERE id = ?', [id]);
    db.changes.add(null);
  }

  Future<void> markError(String id, String error) async {
    await db.customStatement('UPDATE outbox SET error = ? WHERE id = ?', [error, id]);
    db.changes.add(null);
  }

  Future<void> remapId(String oldId, String newId) async {
    final pending = await getPending();
    for (final op in pending) {
      final jsonStr = jsonEncode(op.payload);
      if (jsonStr.contains(oldId)) {
        final remappedStr = jsonStr.replaceAll(oldId, newId);
        final remappedPayload = jsonDecode(remappedStr) as Map<String, dynamic>;
        final newFullPayload = jsonEncode({'type': op.type, 'payload': remappedPayload});
        await db.customStatement(
          'UPDATE outbox SET payload = ? WHERE id = ?',
          [newFullPayload, op.id],
        );
      }
    }
  }

  Future<int> count() async {
    final rows = await db.customSelect('SELECT COUNT(*) as cnt FROM outbox').get();
    return rows.first.read<int>('cnt');
  }
}
