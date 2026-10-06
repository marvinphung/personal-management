import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';

void main() {
  group('Bank snapshot normalization & ledger update tests', () {
    test('applySnapshot correctly maps bank transaction schema, tags, and accounts', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);

      final snapshot = {
        'revision': 12,
        'categories': [
          {
            'id': 'cat-entertainment',
            'direction': 'expense',
            'name': 'Giải trí',
            'icon': 'sports_esports',
            'archived': false,
            'version': 1,
          },
        ],
        'tags': [
          {
            'id': 'tag-movies',
            'category_id': 'cat-entertainment',
            'name': 'Xem phim',
            'archived': false,
            'version': 1,
          },
        ],
        'bank_bindings': [
          {
            'id': 'binding-bidv-1',
            'bank_code': 'bidv',
            'account_number': '8881699211',
            'version': 1,
          },
        ],
        'transactions': [
          {
            'id': 'tx-88k',
            'direction': 'expense',
            'amount_vnd': '88000',
            'occurred_at': '2026-10-05T12:00:00+07:00',
            'source': 'bank',
            'bank_code_snapshot': 'bidv',
            'owner_account_snapshot': '...9211',
            'bank_description': 'MB-TkThe :1234567890, tai NH-A. NGUYEN VAN A Chuyen tien',
            'category_id': 'cat-entertainment',
            'user_note': '',
            'purpose': 'normal',
            'version': 1,
            'tag_ids': ['tag-movies'],
          },
        ],
      };

      await db.applySnapshot(snapshot);

      // Verify category was normalized
      final categories = await db.list(Entity.categories);
      expect(categories.length, 1);
      expect(categories.first.text('type'), 'expense');
      expect(categories.first.text('name'), 'Giải trí');

      // Verify bank account was created
      final accounts = await db.list(Entity.accounts);
      expect(accounts.length, 1);
      expect(accounts.first.id, 'binding-bidv-1');
      expect(accounts.first.text('name'), contains('BIDV'));

      // Verify transaction was normalized
      final txs = await db.list(Entity.transactions);
      expect(txs.length, 1);
      final tx = txs.first;
      expect(tx.id, 'tx-88k');
      expect(tx.text('type'), 'expense');
      expect(tx.money('amount'), 88000);
      expect(tx.text('currency'), 'VND');
      expect(tx.text('description'), contains('NGUYEN VAN A'));
      expect(tx.text('account_id'), 'binding-bidv-1');

      // Verify transaction tags were created
      final tags = await db.list(Entity.transactionTags);
      expect(tags.length, 1);
      expect(tags.first.text('transaction_id'), 'tx-88k');
      expect(tags.first.text('tag_id'), 'tag-movies');

      // Verify Ledger.monthly computes totals correctly
      final monthly = Ledger.monthly(txs, DateTime(2026, 10), 'VND');
      expect(monthly.expense, 88000);
      expect(monthly.income, 0);
      expect(monthly.net, -88000);

      // Verify db.balances() reflects the expense on the account
      final balances = await db.balances();
      expect(balances['binding-bidv-1'], -88000);
    });

    test('R1: Does not assign bank account to manual transactions or ambiguous bank matches', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);

      final snapshot = {
        'revision': 13,
        'bank_bindings': [
          {
            'id': 'binding-vcb-1',
            'bank_code': 'vcb',
            'account_number': '1234567890',
          },
          {
            'id': 'binding-vcb-2',
            'bank_code': 'vcb',
            'account_number': '9876567890', // Same suffix 7890
          },
          {
            'id': 'binding-tcb-1',
            'bank_code': 'tcb',
            'account_number': '5555555555',
          },
        ],
        'transactions': [
          // 1. Manual transaction without bank snapshot -> should have account_id == null
          {
            'id': 'tx-manual',
            'direction': 'expense',
            'amount_vnd': '50000',
            'description': 'Tien cafe sang',
            'source': 'manual',
          },
          // 2. Ambiguous match (two VCB accounts with matching suffix 7890) -> should NOT guess, account_id == null
          {
            'id': 'tx-ambiguous',
            'direction': 'income',
            'amount_vnd': '200000',
            'bank_code_snapshot': 'vcb',
            'owner_account_snapshot': '7890',
          },
          // 3. Unmatched bank code -> account_id == null
          {
            'id': 'tx-unmatched',
            'direction': 'expense',
            'amount_vnd': '30000',
            'bank_code_snapshot': 'acb',
            'owner_account_snapshot': '1111',
          },
          // 4. Single unique match -> should link to binding-tcb-1
          {
            'id': 'tx-unique',
            'direction': 'expense',
            'amount_vnd': '100000',
            'bank_code_snapshot': 'tcb',
            'owner_account_snapshot': '5555',
          },
        ],
      };

      await db.applySnapshot(snapshot);

      final txManual = await db.get(Entity.transactions, 'tx-manual');
      expect(txManual, isNotNull);
      expect(txManual!.text('account_id'), isEmpty);

      final txAmbiguous = await db.get(Entity.transactions, 'tx-ambiguous');
      expect(txAmbiguous, isNotNull);
      expect(txAmbiguous!.text('account_id'), isEmpty);

      final txUnmatched = await db.get(Entity.transactions, 'tx-unmatched');
      expect(txUnmatched, isNotNull);
      expect(txUnmatched!.text('account_id'), isEmpty);

      final txUnique = await db.get(Entity.transactions, 'tx-unique');
      expect(txUnique, isNotNull);
      expect(txUnique!.text('account_id'), 'binding-tcb-1');
    });

    test('R7: Validates amount strictly and does not fake created_at/updated_at', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);

      // Snapshot with missing created_at and updated_at
      final snapshot = {
        'revision': 14,
        'transactions': [
          {
            'id': 'tx-clean-dates',
            'amount': 75000,
            'occurred_at': '2026-10-01T08:00:00Z',
            // No created_at or updated_at
          },
        ],
      };

      await db.applySnapshot(snapshot);
      final tx = await db.get(Entity.transactions, 'tx-clean-dates');
      expect(tx, isNotNull);
      expect(tx!.text('created_at'), isEmpty);
      expect(tx.text('updated_at'), isEmpty);
      expect(tx.dateOrNull('created_at'), isNull);
      expect(tx.dateOrNull('updated_at'), isNull);
      expect(tx.dateOrNull('occurred_at'), isNotNull);

      // Snapshot with invalid/malformed amount must throw FormatException instead of becoming 0
      final badSnapshot = {
        'revision': 15,
        'transactions': [
          {
            'id': 'tx-bad-amount',
            'amount': 'not-a-number',
          },
        ],
      };
      expect(() => db.applySnapshot(badSnapshot), throwsA(isA<FormatException>()));
    });

    test('R8: Preserves dirty outbox records and offline edits across applySnapshot', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);

      // 1. Initial snapshot
      await db.applySnapshot({
        'revision': 1,
        'transactions': [
          {
            'id': 'tx-server-1',
            'amount': 100000,
            'description': 'Original server description',
          },
        ],
      });

      // 2. User edits tx-server-1 offline and creates an offline new transaction tx-offline-new
      final editedTx = Record(Entity.transactions, {
        'id': 'tx-server-1',
        'amount': 100000,
        'description': 'Offline edited description',
        'client_modified_at': '2026-10-05T10:00:00Z',
      });
      final offlineTx = Record(Entity.transactions, {
        'id': 'tx-offline-new',
        'amount': 250000,
        'description': 'Offline created cash expense',
        'client_modified_at': '2026-10-05T10:05:00Z',
      });

      await db.put(editedTx);
      await db.put(offlineTx);

      // Record operations in outbox
      await db.enqueue('op-edit-1', [editedTx]);
      await db.enqueue('op-new-1', [offlineTx]);

      expect(await db.pendingOutboxCount(), 2);

      // 3. New server snapshot arrives that still contains old data for tx-server-1 and does NOT know tx-offline-new
      await db.applySnapshot({
        'revision': 2,
        'transactions': [
          {
            'id': 'tx-server-1',
            'amount': 100000,
            'description': 'Original server description',
          },
          {
            'id': 'tx-server-2',
            'amount': 50000,
            'description': 'New transaction from server',
          },
        ],
      });

      // 4. Verify that:
      // - Offline edited tx-server-1 keeps its offline edit (overlay)
      final checkEdited = await db.get(Entity.transactions, 'tx-server-1');
      expect(checkEdited, isNotNull);
      expect(checkEdited!.text('description'), 'Offline edited description');

      // - Offline new tx-offline-new is NOT deleted by the snapshot
      final checkOffline = await db.get(Entity.transactions, 'tx-offline-new');
      expect(checkOffline, isNotNull);
      expect(checkOffline!.money('amount'), 250000);

      // - New server tx-server-2 was inserted
      final checkServer2 = await db.get(Entity.transactions, 'tx-server-2');
      expect(checkServer2, isNotNull);
      expect(checkServer2!.money('amount'), 50000);

      // - Outbox is intact
      expect(await db.pendingOutboxCount(), 2);
    });
  });
}
