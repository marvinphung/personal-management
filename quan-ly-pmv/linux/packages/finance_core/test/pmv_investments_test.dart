import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/investments/investment_summary.dart';

void main() {
  test(
    'one investment kind combines principal expense and principal+profit income across different tag IDs',
    () {
      final categories = [
        Record(Entity.categories, {
          'id': 'out',
          'behavior': 'investment_expense',
        }),
        Record(Entity.categories, {
          'id': 'in',
          'behavior': 'investment_income',
          'is_archived': true,
        }),
        Record(Entity.categories, {'id': 'other', 'behavior': 'normal'}),
      ];
      Record tx(
        String id,
        String cat,
        String type,
        int amount, {
        String currency = 'VND',
        String date = '2026-11-01',
        bool deleted = false,
      }) => Record(Entity.transactions, {
        'id': id,
        'category_id': cat,
        'type': type,
        'amount': amount,
        'currency': currency,
        'occurred_at': date,
        'deleted_at': deleted ? '2026-11-02' : null,
      });
      final rows = [
        tx('a', 'out', 'expense', 100),
        tx('b', 'in', 'income', 120),
        tx('c', 'other', 'income', 1000),
        tx('d', 'in', 'income', 900, currency: 'USD'),
        tx('e', 'in', 'income', 800, date: '2026-10-01'),
        tx('f', 'in', 'income', 700, deleted: true),
      ];
      final summary = InvestmentSummary.filter(
        transactions: rows,
        categories: categories,
        tags: [
          Record(Entity.tags, {
            'id': 't1',
            'name': 'chungkhoan',
            'category_id': 'out',
          }),
          Record(Entity.tags, {
            'id': 't2',
            'name': 'chungkhoanthu',
            'category_id': 'in',
          }),
        ],
        links: [
          Record(Entity.transactionTags, {
            'transaction_id': 'a',
            'tag_id': 't1',
          }),
          Record(Entity.transactionTags, {
            'transaction_id': 'b',
            'tag_id': 't2',
          }),
        ],
        currency: 'VND',
        kinds: {'Chứng khoán'},
        start: DateTime(2026, 11),
        end: DateTime(2026, 12),
      );
      expect(summary.transactions.map((t) => t.id).toSet(), {'a', 'b'});
      expect(summary.invested, 100);
      expect(summary.returned, 120);
      expect(summary.difference, 20);
    },
  );
}
