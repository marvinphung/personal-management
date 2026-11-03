import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/features/dashboard/daily_spending.dart';
import 'package:finance_core/features/investments/investment_summary.dart';

void main() {
  test(
    'all movements count despite legacy exclusion flags; balances and investments remain exact',
    () {
      final now = DateTime.now();
      Record tx(String id, String type, int amount, bool excluded) =>
          Record.create(Entity.transactions, 'u', {
            'id': id,
            'type': type,
            'amount': amount,
            'account_id': 'a',
            'category_id': 'investment',
            'currency': 'VND',
            'occurred_at': now.toIso8601String(),
            'exclude_from_totals': excluded,
          });
      final rows = [
        tx('a', 'expense', 100, false),
        tx('b', 'expense', 200, true),
        tx('c', 'income', 250, true),
      ];
      final totals = Ledger.monthly(rows, now, 'VND');
      expect(totals.expense, 300);
      expect(totals.income, 250);
      expect(dailySpending(rows, now, 'VND').reduce((a, b) => a + b), 300);
      expect(
        Ledger.balance(
          Record(Entity.accounts, {'id': 'a', 'opening_balance': 1000}),
          rows,
        ),
        950,
      );
      final summary = InvestmentSummary.filter(
        transactions: rows,
        categories: [
          Record(Entity.categories, {
            'id': 'investment',
            'behavior': 'investment_expense',
          }),
        ],
        tags: [],
        links: [],
        currency: 'VND',
      );
      expect(summary.invested, 300);
      expect(summary.returned, 250);
      expect(summary.transactions, hasLength(3));
    },
  );
}
