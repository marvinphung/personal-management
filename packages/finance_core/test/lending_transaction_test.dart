import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/features/debts/debt_service.dart';

void main() {
  test(
    'lending transaction creates one linked debt atomically and retry is idempotent',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final repo = FinanceRepository(db, 'u');
      final account = repo.create(Entity.accounts, {'name': 'MB'});
      final person = repo.create(Entity.people, {'name': 'Nam'});
      final category = repo.create(Entity.categories, {
        'name': 'Cho vay',
        'behavior': 'lending',
      });
      await repo.saveBatch([account, person, category]);
      final tag = repo.create(Entity.tags, {
        'name': 'chobanmuon',
        'category_id': category.id,
      });
      final tx = repo.create(Entity.transactions, {
        'type': 'expense',
        'amount': 1000000,
        'account_id': account.id,
        'category_id': category.id,
        'occurred_at': '2026-09-10T10:00:00Z',
      });
      final service = DebtService(repo);
      await service.saveLendingTransaction(tx, person, [
        tag,
      ], importKey: 'bank:sample');
      await service.saveLendingTransaction(tx, person, [
        tag,
      ], importKey: 'bank:sample');
      final debts = await db.list(Entity.debts);
      final transactions = await db.list(Entity.transactions);
      expect(debts, hasLength(1));
      expect(transactions, hasLength(1));
      expect(debts.single.text('linked_transaction_id'), tx.id);
      expect(debts.single.text('person_id'), person.id);
      expect(debts.single.text('started_at'), tx.text('occurred_at'));
      expect(transactions.single.text('purpose'), 'debt_disbursement');
      expect(
        (await db.pending()).last.rows.map((r) => r.entity),
        containsAll([
          Entity.debts,
          Entity.transactions,
          Entity.tags,
          Entity.transactionTags,
        ]),
      );
      expect(Ledger.monthly(transactions, DateTime(2026, 9), 'VND').expense, 0);
      expect((await db.balances())[account.id], -1000000);
      await service.repay(debts.single, 300000, account: account);
      expect(
        Ledger.remaining(debts.single, await db.list(Entity.debtPayments)),
        700000,
      );
    },
  );
}
