import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/features/debts/debt_service.dart';

void main() {
  group('PMV Debt & Ledger Specifications', () {
    test(
      'Ledger.remaining allows overpayment (negative remaining, no clamp to 0)',
      () {
        final debt = Record(Entity.debts, {
          'id': 'd1',
          'principal_amount': 100000,
          'currency': 'VND',
          'status': 'active',
        });

        // 1. Partial payment
        final p1 = Record(Entity.debtPayments, {
          'id': 'p1',
          'debt_id': 'd1',
          'amount': 40000,
        });
        expect(Ledger.remaining(debt, [p1]), equals(60000));

        // 2. Exact payment
        final p2 = Record(Entity.debtPayments, {
          'id': 'p2',
          'debt_id': 'd1',
          'amount': 60000,
        });
        expect(Ledger.remaining(debt, [p1, p2]), equals(0));

        // 3. Overpayment: total paid = 120,000 > 100,000 -> remaining is -20,000 (NOT clamped to 0)
        final p3 = Record(Entity.debtPayments, {
          'id': 'p3',
          'debt_id': 'd1',
          'amount': 20000,
        });
        expect(Ledger.remaining(debt, [p1, p2, p3]), equals(-20000));
      },
    );

    test('Ledger.debtStatus honors completed status', () {
      final activeDebt = Record(Entity.debts, {
        'id': 'd1',
        'principal_amount': 100000,
        'status': 'active',
      });
      expect(Ledger.debtStatus(activeDebt, []), equals('active'));

      final completedDebt = Record(Entity.debts, {
        'id': 'd2',
        'principal_amount': 100000,
        'status': 'completed',
        'manual_completed_at': DateTime.now().toIso8601String(),
      });
      expect(Ledger.debtStatus(completedDebt, []), equals('completed'));
    });

    test(
      'Ledger.monthly includes debt transactions into totals and excludes transfers',
      () {
        final now = DateTime.now();
        final month = DateTime(now.year, now.month);

        final normalExpense = Record(Entity.transactions, {
          'id': 't1',
          'type': 'expense',
          'purpose': 'normal',
          'amount': 50000,
          'currency': 'VND',
          'occurred_at': now.toIso8601String(),
        });

        final debtDisbursement = Record(Entity.transactions, {
          'id': 't2',
          'type': 'expense',
          'purpose': 'debt_disbursement',
          'amount': 100000,
          'currency': 'VND',
          'occurred_at': now.toIso8601String(),
        });

        final debtRepayment = Record(Entity.transactions, {
          'id': 't3',
          'type': 'income',
          'purpose': 'debt_repayment',
          'amount': 120000,
          'currency': 'VND',
          'occurred_at': now.toIso8601String(),
        });

        final internalTransfer = Record(Entity.transactions, {
          'id': 't4',
          'type': 'transfer',
          'purpose': 'normal',
          'amount': 200000,
          'currency': 'VND',
          'occurred_at': now.toIso8601String(),
        });

        final rows = [
          normalExpense,
          debtDisbursement,
          debtRepayment,
          internalTransfer,
        ];
        final totals = Ledger.monthly(rows, month, 'VND');

        // Expense should include normalExpense (50k) + debtDisbursement (100k) = 150k
        expect(totals.expense, equals(150000));
        // Income should include debtRepayment (120k)
        expect(totals.income, equals(120000));
        // Net = income - expense = 120k - 150k = -30k
        expect(totals.net, equals(-30000));
      },
    );

    for (final direction in DebtDirection.values) {
      test(
        'repository permits overpayment for ${direction.name} and completes only manually',
        () async {
          final db = LocalDatabase.memory();
          addTearDown(db.close);
          final repo = FinanceRepository(db, 'test-user');
          final person = repo.create(Entity.people, {
            'name': 'Synthetic person',
          });
          final account = repo.create(Entity.accounts, {'name': 'Cash'});
          final usd = repo.create(Entity.accounts, {
            'name': 'USD',
            'currency': 'USD',
          });
          await repo.saveBatch([person, account, usd]);
          final service = DebtService(repo);
          final disbursement = repo.create(Entity.transactions, {
            'type': direction == DebtDirection.lent ? 'expense' : 'income',
            'amount': 100000,
            'account_id': account.id,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
          });
          await service.saveDisbursementTransaction(
            disbursement,
            person,
            direction,
            [],
          );
          final debt = (await db.list(Entity.debts)).single;
          final repayment = repo.create(Entity.transactions, {
            'type': direction == DebtDirection.lent ? 'income' : 'expense',
            'amount': 120000,
            'account_id': account.id,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
          });
          await expectLater(
            service.saveRepaymentTransaction(
              repayment.patch({'currency': 'USD', 'account_id': usd.id}),
              debt,
              [],
            ),
            throwsFormatException,
          );
          expect(await db.list(Entity.debtPayments), isEmpty);
          await service.saveRepaymentTransaction(repayment, debt, []);
          final payments = await db.list(Entity.debtPayments);
          expect(payments, hasLength(1));
          expect(Ledger.remaining(debt, payments), -20000);
          expect(
            (await db.get(Entity.debts, debt.id))!.text('status'),
            'active',
          );
          expect(await db.list(Entity.transactions), hasLength(2));
          expect(await db.pending(), hasLength(3));
          await service.markDebtCompleted(debt);
          expect(
            (await db.get(Entity.debts, debt.id))!.text('status'),
            'completed',
          );
        },
      );
    }

    test(
      'DebtService.markDebtCompleted updates status and manual_completed_at',
      () async {
        final db = LocalDatabase.memory();
        final repo = FinanceRepository(db, 'user-123');
        final service = DebtService(repo);

        addTearDown(db.close);
        final person = repo.create(Entity.people, {'name': 'Test'});
        await repo.saveBatch([person]);
        final debt = repo.create(Entity.debts, {
          'person_id': person.id,
          'direction': 'lent',
          'principal_amount': 200000,
          'currency': 'VND',
          'started_at': DateTime.now().toIso8601String(),
          'status': 'active',
        });
        await repo.saveBatch([debt]);

        await service.markDebtCompleted(debt);

        final updated = await db.get(Entity.debts, debt.id);
        expect(updated, isNotNull);
        expect(updated!.text('status'), equals('completed'));
        expect(updated.text('manual_completed_at'), isNotEmpty);
      },
    );
  });
}
