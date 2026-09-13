import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'record.dart';

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
SELECT a.id, CAST(json_extract(a.payload,'\$.opening_balance') AS INTEGER)+COALESCE(SUM(
 CASE WHEN json_extract(t.payload,'\$.type')='transfer' THEN
  CASE WHEN json_extract(t.payload,'\$.to_account_id')=a.id THEN CAST(json_extract(t.payload,'\$.amount') AS INTEGER) ELSE 0 END -
  CASE WHEN json_extract(t.payload,'\$.from_account_id')=a.id THEN CAST(json_extract(t.payload,'\$.amount') AS INTEGER) ELSE 0 END
 ELSE CASE WHEN json_extract(t.payload,'\$.account_id')=a.id THEN
  CAST(json_extract(t.payload,'\$.amount') AS INTEGER)*CASE WHEN json_extract(t.payload,'\$.type')='income' THEN 1 ELSE -1 END ELSE 0 END END),0) AS balance
FROM records a LEFT JOIN records t ON t.entity='transactions' AND json_extract(t.payload,'\$.deleted_at') IS NULL
WHERE a.entity='accounts' AND json_extract(a.payload,'\$.deleted_at') IS NULL GROUP BY a.id
""").get();
    return {
      for (final row in rows) row.read<String>('id'): row.read<int>('balance'),
    };
  }

  Future<void> enqueue(String id, List<Record> rows) async {
    await transaction(() async {
      for (final row in rows) {
        await put(row);
      }
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
