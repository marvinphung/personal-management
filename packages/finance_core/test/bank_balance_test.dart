import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';

void main() {
  test(
    'bank snapshot excludes already included history, rejects stale and mismatched balances',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final repo = FinanceRepository(db, 'user');
      final account = repo.create(Entity.accounts, {
        'name': 'MB',
        'opening_balance': 10,
      });
      await repo.save(account);
      final at = DateTime.utc(2025, 1, 1);
      Map<String, dynamic> snapshot(
        int amount,
        DateTime date, [
        String currency = 'VND',
      ]) => {
        'account': account.id,
        'amount': amount,
        'currency': currency,
        'at': date.millisecondsSinceEpoch,
      };
      await Future.wait([
        repo.applyBankBalance(snapshot(5000, at)),
        repo.applyBankBalance(
          snapshot(100, at.subtract(const Duration(days: 1))),
        ),
      ]);
      final old = repo.create(Entity.transactions, {
        'account_id': account.id,
        'type': 'income',
        'amount': 5000,
        'occurred_at': at.toIso8601String(),
      });
      await repo.saveTransaction(old, []);
      expect((await db.balances())[account.id], 5000);
      await repo.applyBankBalance(
        snapshot(100, at.subtract(const Duration(days: 1))),
      );
      await repo.applyBankBalance(
        snapshot(100, at.add(const Duration(days: 1)), 'USD'),
      );
      expect((await db.balances())[account.id], 5000);
      await repo.saveTransaction(
        old.patch({
          'id': 'later',
          'amount': 200,
          'type': 'expense',
          'occurred_at': at.add(const Duration(hours: 1)).toIso8601String(),
        }),
        [],
      );
      expect((await db.balances())[account.id], 4800);
      expect(
        Ledger.balance(
          (await db.get(Entity.accounts, account.id))!,
          await db.list(Entity.transactions),
        ),
        4800,
      );
      await repo.applyBankBalance(snapshot(0, at.add(const Duration(days: 2))));
      expect((await db.balances())[account.id], 0);
    },
  );
}
