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
            'bank_description': 'SMB-TkThe :0386883005, tai MSCBVNVX. PHUNG MINH VU Chuyen tien',
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
      expect(tx.text('description'), contains('PHUNG MINH VU'));
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
  });
}
