import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'record.dart';
import 'package:uuid/uuid.dart';

/// Drift owns SQLite connections/transactions. Domain JSON and durable outbox are
/// separate, with indexed projected fields for pagination and calendar queries.
class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);
  factory LocalDatabase.file(File file) =>
      LocalDatabase(NativeDatabase.createInBackground(file));
  factory LocalDatabase.memory() => LocalDatabase(NativeDatabase.memory());
  final changes = StreamController<void>.broadcast();
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE records (entity TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(entity,id))',
      );
      await customStatement(
        "CREATE INDEX record_date ON records(entity,json_extract(payload,'\$.occurred_at') DESC,id)",
      );
      await customStatement(
        'CREATE TABLE outbox (sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, payload TEXT NOT NULL, error TEXT)',
      );
      await customStatement(
        'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL');
      await customStatement('PRAGMA secure_delete=ON');

      // Migration / self-healing: if legacy un-normalized data exists or format version is outdated,
      // reset revision so next sync pulls a fresh snapshot and normalizes everything.
      try {
        final rows = await customSelect(
          "SELECT value FROM metadata WHERE key = 'data_format_version'",
        ).get();
        if (rows.isEmpty || (int.tryParse(rows.first.read<String>('value')) ?? 0) < 2) {
          await customStatement("DELETE FROM metadata WHERE key = 'revision'");
          await customStatement(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES('data_format_version', '2')",
          );
        }
      } catch (_) {}
    },
  );
  Future<void> put(Record record) => customStatement(
    'INSERT INTO records(entity,id,payload) VALUES(?,?,?) ON CONFLICT(entity,id) DO UPDATE SET payload=excluded.payload',
    [record.entity.table, record.id, jsonEncode(record.data)],
  );
  Future<Record?> get(Entity entity, String id) async {
    final rows = await customSelect(
      'SELECT payload FROM records WHERE entity=? AND id=?',
      variables: [Variable(entity.table), Variable(id)],
    ).get();
    return rows.isEmpty
        ? null
        : Record(entity, jsonDecode(rows.first.read<String>('payload')));
  }

  Future<List<Record>> list(
    Entity entity, {
    bool includeDeleted = false,
    int? limit,
    int offset = 0,
    DateTime? month,
  }) async {
    final args = <Variable>[Variable(entity.table)];
    var where = 'entity=?';
    if (!includeDeleted) {
      where += " AND json_extract(payload,'\$.deleted_at') IS NULL";
    }
    if (month != null) {
      where +=
          " AND json_extract(payload,'\$.occurred_at')>=? AND json_extract(payload,'\$.occurred_at')<?";
      args.addAll([
        Variable(DateTime(month.year, month.month).toUtc().toIso8601String()),
        Variable(
          DateTime(month.year, month.month + 1).toUtc().toIso8601String(),
        ),
      ]);
    }
    var sql =
        "SELECT payload FROM records WHERE $where ORDER BY json_extract(payload,'\$.occurred_at') DESC,id";
    if (limit != null) {
      sql += ' LIMIT ? OFFSET ?';
      args.addAll([Variable(limit), Variable(offset)]);
    }
    return (await customSelect(sql, variables: args).get())
        .map((r) => Record(entity, jsonDecode(r.read<String>('payload'))))
        .toList();
  }

  Future<Map<String, int>> balances() async {
    final rows = await customSelect("""
SELECT a.id, CAST(COALESCE(json_extract(a.payload,'\$.bank_balance'),json_extract(a.payload,'\$.opening_balance')) AS INTEGER)+COALESCE(SUM(
 CASE WHEN json_extract(t.payload,'\$.type')='transfer' THEN
  CASE WHEN json_extract(t.payload,'\$.to_account_id')=a.id THEN CAST(json_extract(t.payload,'\$.amount') AS INTEGER) ELSE 0 END -
  CASE WHEN json_extract(t.payload,'\$.from_account_id')=a.id THEN CAST(json_extract(t.payload,'\$.amount') AS INTEGER) ELSE 0 END
 ELSE CASE WHEN json_extract(t.payload,'\$.account_id')=a.id THEN
  CAST(json_extract(t.payload,'\$.amount') AS INTEGER)*CASE WHEN json_extract(t.payload,'\$.type')='income' THEN 1 ELSE -1 END ELSE 0 END END),0) AS balance
FROM records a LEFT JOIN records t ON t.entity='transactions' AND json_extract(t.payload,'\$.deleted_at') IS NULL AND julianday(json_extract(t.payload,'\$.occurred_at')) <= julianday('now') AND (json_extract(a.payload,'\$.bank_balance_at') IS NULL OR julianday(json_extract(t.payload,'\$.occurred_at')) > julianday(json_extract(a.payload,'\$.bank_balance_at')))
WHERE a.entity='accounts' AND json_extract(a.payload,'\$.deleted_at') IS NULL GROUP BY a.id
""").get();
    return {
      for (final row in rows) row.read<String>('id'): row.read<int>('balance'),
    };
  }

  Future<void> enqueue(String id, List<Record> rows, {String? receipt}) async {
    await transaction(() async {
      for (final row in rows) {
        await put(row);
      }
      if (receipt != null) await setMetadata(receipt, id);
      await customStatement('INSERT INTO outbox(id,payload) VALUES(?,?)', [
        id,
        jsonEncode(rows.map((r) => r.change).toList()),
      ]);
    });
    changes.add(null);
  }

  Future<List<PendingOperation>> pending() async =>
      (await customSelect('SELECT * FROM outbox ORDER BY sequence').get())
          .map(
            (r) => PendingOperation(
              r.read<String>('id'),
              (jsonDecode(r.read<String>('payload')) as List)
                  .map(
                    (c) => Record(
                      EntityTable.parse(c['table']),
                      Map<String, dynamic>.from(c['data']),
                    ),
                  )
                  .toList(),
              r.readNullable<String>('error'),
            ),
          )
          .toList();
  Future<void> acknowledge(String id) async {
    await customStatement('DELETE FROM outbox WHERE id=?', [id]);
    changes.add(null);
  }

  Future<void> reject(PendingOperation operation) async {
    await transaction(() async {
      for (final row in operation.rows) {
        // Do not erase an edit made while this operation was in flight.
        await customStatement(
          "DELETE FROM records WHERE entity=? AND id=? AND json_extract(payload,'\$.mutation_id')=?",
          [row.entity.table, row.id, row.text('mutation_id')],
        );
      }
      await customStatement('DELETE FROM outbox WHERE id=?', [operation.id]);
    });
    changes.add(null);
  }

  Future<void> failed(String id) async {
    await customStatement('UPDATE outbox SET error=? WHERE id=?', [
      'Unable to sync. Check connection or review the change.',
      id,
    ]);
    changes.add(null);
  }

  Future<void> mergeRemote(List<Record> rows) async {
    await transaction(() async {
      final dirty = (await pending())
          .expand((p) => p.rows)
          .map((r) => '${r.entity.table}/${r.id}')
          .toSet();
      for (final row in rows) {
        if (!dirty.contains('${row.entity.table}/${row.id}')) await put(row);
      }
    });
    changes.add(null);
  }

  Future<String?> metadata(String key) async => (await customSelect(
    'SELECT value FROM metadata WHERE key=?',
    variables: [Variable(key)],
  ).getSingleOrNull())?.read<String>('value');
  Future<void> applySnapshot(Map<String, dynamic> snapshot) async {
    final revision = snapshot['revision'] as int;
    await transaction(() async {
      // 0. Accounts
      if (snapshot.containsKey('accounts')) {
        await customStatement("DELETE FROM records WHERE entity = 'accounts'");
        final accounts = snapshot['accounts'] as List;
        for (final a in accounts) {
          final data = Map<String, dynamic>.from(a as Map);
          if (data['deleted_at'] == null) {
            await put(Record(Entity.accounts, data));
          }
        }
      }

      // 1. Categories
      if (snapshot.containsKey('categories')) {
        await customStatement("DELETE FROM records WHERE entity = 'categories'");
        final cats = snapshot['categories'] as List;
        for (final cat in cats) {
          final data = Map<String, dynamic>.from(cat as Map);
          final type = data['type'] ?? data['direction'];
          if (type != null) data['type'] = type;
          await put(Record(Entity.categories, data));
        }
      }

      // 2. Tags
      if (snapshot.containsKey('tags')) {
        await customStatement("DELETE FROM records WHERE entity = 'tags'");
        final tags = snapshot['tags'] as List;
        for (final tag in tags) {
          final data = Map<String, dynamic>.from(tag as Map);
          await put(Record(Entity.tags, data));
        }
      }

      // 3. Bank bindings
      var bankBindingList = <Map<String, dynamic>>[];
      if (snapshot.containsKey('bank_bindings')) {
        await customStatement("DELETE FROM records WHERE entity = 'bank_bindings'");
        final bindings = snapshot['bank_bindings'] as List;
        for (final b in bindings) {
          final data = Map<String, dynamic>.from(b as Map);
          await put(Record(Entity.bankBindings, data));
          bankBindingList.add(data);

          // Ensure a matching Account exists for this bank binding in Entity.accounts
          final bankCode = (data['bank_code'] ?? '').toString().toUpperCase();
          final accNum = (data['account_number'] ?? '').toString();
          final bindingId = data['id']?.toString() ?? '';
          final accountName = accNum.isNotEmpty ? '$bankCode ($accNum)' : bankCode;

          final existingAcc = await get(Entity.accounts, bindingId);
          if (existingAcc == null) {
            await put(Record(Entity.accounts, {
              'id': bindingId,
              'name': accountName,
              'type': 'bank',
              'currency': 'VND',
              'opening_balance': 0,
              'bank_code': data['bank_code'],
              'account_number': accNum,
              'is_archived': false,
            }));
          } else {
            await put(existingAcc.patch({
              'name': accountName,
              'bank_code': data['bank_code'],
              'account_number': accNum,
            }));
          }
        }
      } else {
        final existingBindings = await list(Entity.bankBindings);
        bankBindingList = existingBindings.map((r) => r.data).toList();
      }

      // 4. Transactions and transaction tags
      if (snapshot.containsKey('transactions')) {
        await customStatement("DELETE FROM records WHERE entity = 'transactions'");
        await customStatement("DELETE FROM records WHERE entity = 'transaction_tags'");
        final txs = snapshot['transactions'] as List;
        for (final tx in txs) {
          final data = Map<String, dynamic>.from(tx as Map);
          final txId = data['id'].toString();
          final type = data['type'] ?? data['direction'] ?? 'expense';
          final amount = data['amount'] ?? int.tryParse(data['amount_vnd']?.toString() ?? '') ?? 0;
          final currency = data['currency'] ?? 'VND';
          final desc = (data['description'] != null && data['description'].toString().isNotEmpty)
              ? data['description'].toString()
              : ((data['user_note'] != null && data['user_note'].toString().isNotEmpty)
                  ? data['user_note'].toString()
                  : (data['bank_description']?.toString() ?? ''));
          data['type'] = type;
          data['amount'] = amount;
          data['currency'] = currency;
          data['description'] = desc;
          data['note'] = data['note'] ?? data['user_note'] ?? '';
          data['purpose'] = data['purpose'] ?? 'normal';
          data['created_at'] = data['created_at'] ?? data['occurred_at'] ?? DateTime.now().toUtc().toIso8601String();
          data['updated_at'] = data['updated_at'] ?? data['occurred_at'] ?? DateTime.now().toUtc().toIso8601String();

          if (data['occurred_at'] != null) {
            final dt = DateTime.tryParse(data['occurred_at'].toString());
            if (dt != null) {
              data['occurred_at'] = dt.toUtc().toIso8601String();
            }
          }

          // Link to account from bank bindings if missing
          if ((data['account_id'] == null || data['account_id'].toString().isEmpty) && bankBindingList.isNotEmpty) {
            final bankCode = (data['bank_code_snapshot'] ?? '').toString().toLowerCase();
            final ownerAcc = (data['owner_account_snapshot'] ?? '').toString().replaceAll('.', '');
            final matchingBinding = bankBindingList.firstWhere(
              (b) {
                final bCode = (b['bank_code'] ?? '').toString().toLowerCase();
                final bNum = (b['account_number'] ?? '').toString();
                if (bankCode.isNotEmpty && bCode != bankCode) return false;
                if (ownerAcc.isNotEmpty) {
                  return bNum.endsWith(ownerAcc) || ownerAcc.endsWith(bNum);
                }
                return bankCode.isNotEmpty && bCode == bankCode;
              },
              orElse: () => bankBindingList.first,
            );
            data['account_id'] = matchingBinding['id'].toString();
          }

          await put(Record(Entity.transactions, data));

          final tagIds = data['tag_ids'];
          if (tagIds is List) {
            for (final tagId in tagIds) {
              final linkId = const Uuid().v5(
                Namespace.url.value,
                'finance:$txId:$tagId',
              );
              await put(Record(Entity.transactionTags, {
                'id': linkId,
                'transaction_id': txId,
                'tag_id': tagId.toString(),
              }));
            }
          }
        }
      }

      // 5. Pending bank events with local undo/outbox overlay
      if (snapshot.containsKey('pending_bank_events')) {
        final hiddenIds = <String>{};
        final undoRaw = await metadata('active_undo_slot');
        if (undoRaw != null && undoRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(undoRaw);
            if (decoded is Map && decoded['event_id'] != null) {
              hiddenIds.add(decoded['event_id'].toString());
            }
          } catch (_) {}
        }

        final outboxRows = await customSelect(
          "SELECT payload FROM outbox WHERE json_extract(payload, '\$.type') IN ('discard_pending', 'accept_pending')",
        ).get();
        for (final r in outboxRows) {
          try {
            final p = jsonDecode(r.read<String>('payload'));
            if (p is Map && p['pending_id'] != null) {
              hiddenIds.add(p['pending_id'].toString());
            }
          } catch (_) {}
        }

        await customStatement("DELETE FROM records WHERE entity = 'pending_bank_events'");
        final events = snapshot['pending_bank_events'] as List;
        for (final ev in events) {
          final data = Map<String, dynamic>.from(ev as Map);
          final id = data['id']?.toString();
          if (id != null && hiddenIds.contains(id)) {
            continue;
          }
          await put(Record(Entity.pendingBankEvents, data));
        }
      }

      // 6. Update revision in metadata
      await setMetadata('revision', revision.toString());
      if (snapshot.containsKey('inbox_revision')) {
        await setMetadata('inbox_revision', snapshot['inbox_revision'].toString());
      }
    });
    changes.add(null);
  }

  Future<void> applyInboxSnapshot(
    int inboxRevision,
    List<Map<String, dynamic>> rawEvents,
  ) async {
    await transaction(() async {
      final hiddenIds = <String>{};
      final undoRaw = await metadata('active_undo_slot');
      if (undoRaw != null && undoRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(undoRaw);
          if (decoded is Map && decoded['event_id'] != null) {
            hiddenIds.add(decoded['event_id'].toString());
          }
        } catch (_) {}
      }

      final outboxRows = await customSelect(
        "SELECT payload FROM outbox WHERE json_extract(payload, '\$.type') IN ('discard_pending', 'accept_pending')",
      ).get();
      for (final r in outboxRows) {
        try {
          final p = jsonDecode(r.read<String>('payload'));
          if (p is Map && p['pending_id'] != null) {
            hiddenIds.add(p['pending_id'].toString());
          }
        } catch (_) {}
      }

      await customStatement("DELETE FROM records WHERE entity = 'pending_bank_events'");
      for (final ev in rawEvents) {
        final id = ev['id']?.toString();
        if (id != null && hiddenIds.contains(id)) {
          continue;
        }
        await put(Record(Entity.pendingBankEvents, ev));
      }
      await setMetadata('inbox_revision', inboxRevision.toString());
    });
    changes.add(null);
  }

  Future<void> setMetadata(String key, String value) => customStatement(
    'INSERT INTO metadata(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );

  Future<void> clearPrivate() async {
    await transaction(() async {
      for (final table in ['records', 'outbox', 'metadata']) {
        await customStatement('DELETE FROM $table');
      }
    });
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    changes.add(null);
  }

  @override
  Future<void> close() async {
    await changes.close();
    await super.close();
  }
}

class PendingOperation {
  final String id;
  final List<Record> rows;
  final String? error;
  PendingOperation(this.id, this.rows, this.error);
}
