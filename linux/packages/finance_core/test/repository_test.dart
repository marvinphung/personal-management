import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/debts/debt_service.dart';
import 'package:finance_core/core/utils/ledger.dart';

class FakeRemote implements RemoteStore {
  bool offline = false, conflict = false;
  final Map<String, Record> rows = {};
  final Set<String> receipts = {};
  @override
  Future<void> defaults() async {
    if (offline) throw StateError('offline');
  }

  @override
  Future<bool> push(PendingOperation op) async {
    if (offline) throw StateError('offline');
    if (receipts.add(op.id) && !conflict) {
      for (final row in op.rows) {
        rows['${row.entity.table}/${row.id}'] = row;
      }
    }
    return conflict;
  }

  @override
  Future<List<Record>> pull(Entity e, int offset, int limit) async =>
      rows.values.where((r) => r.entity == e).skip(offset).take(limit).toList();
}

void main() {
  // Independent in-memory connections intentionally simulate multiple devices.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late LocalDatabase db;
  late FinanceRepository repo;
  late FakeRemote remote;
  late SyncEngine sync;
  setUp(() {
    db = LocalDatabase.memory();
    repo = FinanceRepository(db, 'user');
    remote = FakeRemote();
    sync = SyncEngine(db, remote);
  });
  tearDown(() async {
    await sync.stop();
    sync.dispose();
    await db.close();
  });
  test(
    'local create, update, soft delete and outbox are persistent SQL state',
    () async {
      final a = repo.create(Entity.accounts, {'name': 'Cash'});
      await repo.save(a);
      expect((await db.list(Entity.accounts)).single.text('name'), 'Cash');
      expect(await db.pending(), hasLength(1));
      await repo.save(a.patch({'name': 'Wallet'}));
      expect((await db.get(Entity.accounts, a.id))!.text('name'), 'Wallet');
      await repo.remove(a);
      expect(await db.list(Entity.accounts), isEmpty);
      expect(
        (await db.list(Entity.accounts, includeDeleted: true)).single.deleted,
        true,
      );
      expect(await db.pending(), hasLength(3));
    },
  );
  test(
    'offline writes survive failed sync then reach another device',
    () async {
      remote.offline = true;
      final a = repo.create(Entity.accounts, {'name': 'MB Bank'});
      await repo.save(a);
      final tx = repo.create(Entity.transactions, {
        'type': 'expense',
        'amount': 72000,
        'account_id': a.id,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'description': 'Grab',
      });
      await repo.save(tx);
      await sync.sync();
      expect(sync.error, isNotNull);
      expect(await db.pending(), hasLength(2));
      expect(await db.list(Entity.transactions), hasLength(1));
      remote.offline = false;
      await sync.sync();
      expect(await db.pending(), isEmpty);
      expect(await db.metadata('last_successful_sync'), isNotNull);
      final other = LocalDatabase.memory();
      final receiver = SyncEngine(other, remote);
      await receiver.sync();
      expect(
        (await other.list(Entity.transactions)).single.money('amount'),
        72000,
      );
      await receiver.stop();
      receiver.dispose();
      await other.close();
    },
  );
  test(
    'pull applies remote update and tombstone but preserves pending writes',
    () async {
      final a = repo.create(Entity.accounts, {'name': 'Cash'});
      await repo.save(a);
      await sync.sync();
      remote.rows['accounts/${a.id}'] = a.patch({'name': 'Remote'});
      await sync.sync();
      expect((await db.get(Entity.accounts, a.id))!.text('name'), 'Remote');
      await repo.save(a.patch({'name': 'Pending'}));
      await db.mergeRemote([
        a.patch({'name': 'Must not overwrite'}),
      ]);
      expect((await db.get(Entity.accounts, a.id))!.text('name'), 'Pending');
      await sync.sync();
      remote.rows['accounts/${a.id}'] = a.patch({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      });
      await sync.sync();
      expect(await db.list(Entity.accounts), isEmpty);
    },
  );
  test(
    'conflict refreshes server winner and clears losing operation',
    () async {
      final a = repo.create(Entity.accounts, {'name': 'Cash'});
      await repo.save(a);
      await sync.sync();
      await repo.save(a.patch({'name': 'Offline edit'}));
      remote.conflict = true;
      await sync.sync();
      expect((await db.list(Entity.accounts)).single.text('name'), 'Cash');
      expect(await db.pending(), isEmpty);
      expect(sync.notice, isNotNull);
    },
  );
  test(
    'debt and linked cash movement form one atomic outbox operation',
    () async {
      final person = repo.create(Entity.people, {'name': 'Nam'}),
          account = repo.create(Entity.accounts, {
            'name': 'Bank',
            'opening_balance': 2000000,
          });
      await repo.save(person);
      await repo.save(account);
      final service = DebtService(repo);
      await service.createDebt(
        person: person,
        direction: DebtDirection.lent,
        amount: 1000000,
        currency: 'VND',
        account: account,
      );
      expect((await db.pending()).last.rows, hasLength(2));
      final debt = (await db.list(Entity.debts)).single;
      await service.repay(debt, 300000, account: account);
      expect(
        Ledger.remaining(debt, await db.list(Entity.debtPayments)),
        700000,
      );
      expect((await db.balances())[account.id], 1300000);
      final totals = Ledger.monthly(
        await db.list(Entity.transactions),
        DateTime.now(),
        'VND',
      );
      expect(totals.income, 0);
      expect(totals.expense, 0);
      await expectLater(
        service.repay(debt, 800000, account: account),
        throwsFormatException,
      );
      expect(await db.list(Entity.debtPayments), hasLength(1));
    },
  );
  test(
    'clear private removes records, outbox and synchronization metadata',
    () async {
      final category = repo.create(Entity.categories, {'name': 'Học tập'});
      await repo.save(category);
      await repo.save(
        repo.create(Entity.tags, {
          'name': 'university',
          'category_id': category.id,
        }),
      );
      await db.setMetadata('owner', 'user');
      await db.clearPrivate();
      expect(await db.list(Entity.tags), isEmpty);
      expect(await db.pending(), isEmpty);
      expect(await db.metadata('owner'), isNull);
    },
  );
}
