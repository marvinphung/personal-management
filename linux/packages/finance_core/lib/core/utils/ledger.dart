import '../database/record.dart';

class MonthlyTotals {
  final int income, expense;
  const MonthlyTotals(this.income, this.expense);
  int get net => income - expense;
  String get savingRate {
    if (income <= 0) return '—';
    final tenths =
        BigInt.from(net).abs() * BigInt.from(1000) ~/ BigInt.from(income);
    return '${net < 0 ? '-' : ''}${tenths ~/ BigInt.from(10)}.${tenths % BigInt.from(10)}%';
  }
}

class Ledger {
  static bool isScheduled(Record t, {DateTime? now}) =>
      t.data['installment_group'] != null &&
      t.date('occurred_at').isAfter(now ?? DateTime.now());

  static int balance(Record account, Iterable<Record> transactions) =>
      transactions
          .where(
            (t) =>
                !t.deleted &&
                !t.date('occurred_at').isAfter(DateTime.now()) &&
                (account.data['bank_balance_at'] == null ||
                    t
                        .date('occurred_at')
                        .isAfter(account.date('bank_balance_at'))),
          )
          .fold(
            account.data['bank_balance'] != null
                ? account.money('bank_balance')
                : account.money('opening_balance'),
            (sum, t) {
              final amount = t.money('amount');
              if (t.text('type') == 'transfer') {
                return sum +
                    (t.text('to_account_id') == account.id ? amount : 0) -
                    (t.text('from_account_id') == account.id ? amount : 0);
              }
              if (t.text('account_id') != account.id) return sum;
              return sum + (t.text('type') == 'income' ? amount : -amount);
            },
          );
  static MonthlyTotals monthly(
    Iterable<Record> transactions,
    DateTime month,
    String currency,
  ) {
    final start = DateTime(month.year, month.month),
        end = DateTime(month.year, month.month + 1);
    var income = 0, expense = 0;
    for (final t in transactions) {
      if (t.deleted ||
          isScheduled(t) ||
          t.text('currency') != currency ||
          t.text('purpose') != 'normal') {
        continue;
      }
      final date = t.date('occurred_at');
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      if (t.text('type') == 'income') income += t.money('amount');
      if (t.text('type') == 'expense') expense += t.money('amount');
    }
    return MonthlyTotals(income, expense);
  }

  static int remaining(Record debt, Iterable<Record> payments) =>
      debt.money('principal_amount') -
      payments
          .where((p) => !p.deleted && p.text('debt_id') == debt.id)
          .fold(0, (s, p) => s + p.money('amount'));
  static String debtStatus(Record debt, Iterable<Record> payments) {
    if (debt.text('status') == 'cancelled') return 'cancelled';
    final left = remaining(debt, payments);
    return left == 0
        ? 'paid'
        : left == debt.money('principal_amount')
        ? 'active'
        : 'partially_paid';
  }
}
