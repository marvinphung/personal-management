import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/dashboard/daily_spending.dart';

void main() {
  test('daily totals include zero days and exclude other money movements', () {
    Record tx(
      String type,
      int amount, {
      String purpose = 'normal',
      String currency = 'VND',
      int day = 1,
    }) => Record.create(Entity.transactions, 'u', {
      'type': type,
      'amount': amount,
      'purpose': purpose,
      'currency': currency,
      'occurred_at': DateTime(2024, 2, day).toUtc().toIso8601String(),
    });
    final days = dailySpending(
      [
        tx('expense', 45000),
        tx('expense', 5000),
        tx('expense', 12000, day: 29),
        tx('income', 100000),
        tx('transfer', 9000),
        tx('expense', 1000, purpose: 'debt_disbursement'),
        tx('expense', 1999, currency: 'USD'),
        tx(
          'expense',
          500,
        ).patch({'deleted_at': DateTime.now().toIso8601String()}),
        tx('expense', 500, day: 30),
      ],
      DateTime(2024, 2),
      'VND',
    );
    expect(days.length, 29);
    expect(days[0], 50000);
    expect(days[1], 0);
    expect(days[28], 12000);
    expect(days.reduce((a, b) => a + b), 62000);
  });
}
