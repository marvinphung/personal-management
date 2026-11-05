import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';

void main() {
  test('small negative saving rate keeps its sign', () {
    expect(const MonthlyTotals(1000, 1001).savingRate, '-0.1%');
  });
  final account = Record.create(Entity.accounts, 'u', {
    'name': 'MB Bank',
    'opening_balance': 1000000,
  }, id: 'bank');
  Record tx(
    String type,
    int amount, {
    String purpose = 'normal',
    String? from,
    String? to,
    DateTime? date,
  }) => Record.create(Entity.transactions, 'u', {
    'type': type,
    'amount': amount,
    'account_id': type == 'transfer' ? null : 'bank',
    'from_account_id': from,
    'to_account_id': to,
    'purpose': purpose,
    'occurred_at': (date ?? DateTime(2026, 9, 10)).toUtc().toIso8601String(),
  });
  test(
    'expense reduces ledger balance',
    () => expect(Ledger.balance(account, [tx('expense', 45000)]), 955000),
  );
  test(
    'income increases ledger balance',
    () => expect(Ledger.balance(account, [tx('income', 15000000)]), 16000000),
  );
  test('transfer moves money between accounts without income or expense', () {
    final transfer = tx('transfer', 200000, from: 'bank', to: 'cash');
    final cash = Record.create(Entity.accounts, 'u', {
      'name': 'Cash',
    }, id: 'cash');
    expect(Ledger.balance(account, [transfer]), 800000);
    expect(Ledger.balance(cash, [transfer]), 200000);
    final totals = Ledger.monthly([transfer], DateTime(2026, 9), 'VND');
    expect(totals.income, 0);
    expect(totals.expense, 0);
  });
  test('monthly totals exclude debt principal and classify local month', () {
    final rows = [
      tx('income', 1000),
      tx('expense', 400),
      tx('expense', 900, purpose: 'debt_disbursement'),
      tx('income', 300, purpose: 'debt_repayment'),
      tx('income', 500, date: DateTime(2026, 10)),
      tx('expense', 100, date: DateTime(2026, 8, 31, 23, 59)),
    ];
    final totals = Ledger.monthly(rows, DateTime(2026, 9), 'VND');
    expect(totals.income, 1000);
    expect(totals.expense, 400);
    expect(totals.net, 600);
    expect(totals.savingRate, '60.0%');
  });
  test(
    'deleted transactions do not alter balance',
    () => expect(
      Ledger.balance(account, [
        tx(
          'expense',
          100,
        ).patch({'deleted_at': DateTime.now().toIso8601String()}),
      ]),
      1000000,
    ),
  );
  test('partial repayments derive remaining debt and status', () {
    final debt = Record.create(Entity.debts, 'u', {
      'principal_amount': 1000000,
    }, id: 'debt');
    final payments = [
      Record.create(Entity.debtPayments, 'u', {
        'debt_id': 'debt',
        'amount': 300000,
      }),
      Record.create(Entity.debtPayments, 'u', {
        'debt_id': 'debt',
        'amount': 200000,
      }),
    ];
    expect(Ledger.remaining(debt, payments), 500000);
    expect(Ledger.debtStatus(debt, payments), 'partially_paid');
    expect(Ledger.remaining(debt, payments.take(1)), 700000);
  });
}
