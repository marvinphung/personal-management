import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/features/debts/debt_service.dart';

void main() {
  for (final direction in DebtDirection.values) {
    test(
      '${direction.name}: backdated principal and repayment save linked dates; edits retain history and always count',
      () async {
        final db = LocalDatabase.memory();
        addTearDown(db.close);
        final repo = FinanceRepository(db, 'u');
        final person = repo.create(Entity.people, {'name': 'Person'});
        await repo.save(person);
        final service = DebtService(repo);
        final originalDate = DateTime(2024, 1, 31, 9, 30);
        await service.createDebt(
          person: person,
          direction: direction,
          amount: 1000,
          currency: 'VND',
          startedAt: originalDate,
        );
        var debt = (await db.list(Entity.debts)).single;
        var movement = (await db.list(Entity.transactions)).single;
        expect(debt.date('started_at'), originalDate);
        expect(movement.date('occurred_at'), originalDate);
        expect(movement.date('created_at').isAfter(originalDate), isTrue);
        final paid = DateTime(2024, 2, 2, 10);
        await service.repay(debt, 200, paidAt: paid);
        final payment = (await db.list(Entity.debtPayments)).single;
        final repayment = (await db.get(
          Entity.transactions,
          payment.text('linked_transaction_id'),
        ))!;
        expect(payment.date('paid_at'), paid);
        expect(repayment.date('occurred_at'), paid);
        final pendingBefore = (await db.pending()).length;
        final newDate = DateTime(2024, 1, 30, 8);
        await service.updateDebt(
          debt,
          person: person,
          direction: direction,
          amount: 900,
          startedAt: newDate,
          note: 'Updated',
        );
        debt = (await db.get(Entity.debts, debt.id))!;
        movement = (await db.get(
          Entity.transactions,
          debt.text('linked_transaction_id'),
        ))!;
        expect(debt.date('started_at'), newDate);
        expect(movement.date('occurred_at'), newDate);
        expect(debt.money('principal_amount'), 900);
        expect(movement.money('amount'), 900);
        expect(Ledger.remaining(debt, await db.list(Entity.debtPayments)), 700);
        expect((await db.pending()).length, pendingBefore + 1);
        expect(
          (await db.get(Entity.debtPayments, payment.id))!.date('paid_at'),
          paid,
        );
        final jan = Ledger.monthly(
          await db.list(Entity.transactions),
          DateTime(2024, 1),
          'VND',
        );
        final feb = Ledger.monthly(
          await db.list(Entity.transactions),
          DateTime(2024, 2),
          'VND',
        );
        expect(direction == DebtDirection.lent ? jan.expense : jan.income, 900);
        expect(direction == DebtDirection.lent ? feb.income : feb.expense, 200);
        expect(
          (await db.list(
            Entity.transactions,
          )).every((t) => !t.flag('exclude_from_totals')),
          isTrue,
        );
      },
    );
  }
  test(
    'bank-captured debt date cannot change, equivalent timestamps still allow note edits',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final repo = FinanceRepository(db, 'u');
      final person = repo.create(Entity.people, {'name': 'Person'});
      final account = repo.create(Entity.accounts, {'name': 'Bank'});
      await repo.saveBatch([person, account]);
      final service = DebtService(repo);
      final tx = repo.create(Entity.transactions, {
        'type': 'expense',
        'amount': 1000,
        'account_id': account.id,
        'occurred_at': '2024-01-31T09:00:00+00:00',
        'bank_source': {'test': true},
      });
      await service.saveDisbursementTransaction(
        tx,
        person,
        DebtDirection.lent,
        [],
      );
      final d = (await db.list(Entity.debts)).single;
      await service.updateDebt(
        d,
        person: person,
        direction: DebtDirection.lent,
        amount: 1000,
        account: account,
        startedAt: DateTime.parse('2024-01-31T09:00:00Z'),
        note: 'Note',
      );
      await expectLater(
        service.updateDebt(
          d,
          person: person,
          direction: DebtDirection.lent,
          amount: 1000,
          account: account,
          startedAt: DateTime(2024, 1, 30),
        ),
        throwsFormatException,
      );
    },
  );
}
