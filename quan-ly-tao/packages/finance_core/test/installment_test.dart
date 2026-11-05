import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/transactions/installments.dart';

void main() {
  test('monthly amount is repeated from next month, clamping short months', () {
    final dates = Installments.dates(DateTime(2026, 12, 5), 3, 31);
    expect(dates, [
      DateTime(2027, 1, 31),
      DateTime(2027, 2, 28),
      DateTime(2027, 3, 31),
    ]);
    expect(
      Installments.dates(DateTime(2026, 9, 14), 6, 24).last,
      DateTime(2027, 3, 24),
    );
  });
  test(
    'all installments and tags are atomic and future payments do not reduce cash',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final repo = FinanceRepository(db, 'user');
      final account = repo.create(Entity.accounts, {
        'name': 'Bank',
        'opening_balance': 1000000,
      });
      await repo.save(account);
      final template = repo.create(Entity.transactions, {
        'type': 'expense',
        'amount': 100000,
        'account_id': account.id,
        'occurred_at': DateTime(2090, 1, 1).toUtc().toIso8601String(),
      });
      await Installments.save(repo, template, [], months: 6, day: 24);
      final rows = await db.list(Entity.transactions);
      expect(rows, hasLength(6));
      expect(rows.every((r) => r.money('amount') == 100000), true);
      expect((await db.pending()).last.rows, hasLength(6));
      expect((await db.balances())[account.id], 1000000);
      expect(Ledger.monthly(rows, DateTime(2090, 2), 'VND').expense, 0);
      await Installments.save(repo, template, [], months: 6, day: 24);
      expect(await db.list(Entity.transactions), hasLength(6));
    },
  );
}
