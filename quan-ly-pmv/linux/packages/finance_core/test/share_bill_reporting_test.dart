import 'package:flutter/material.dart';
import 'package:finance_core/app/theme.dart';
import 'package:finance_core/core/utils/money.dart';
import 'package:finance_core/features/dashboard/category_chart.dart';
import 'package:finance_core/features/dashboard/spending_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/ledger.dart';
import 'package:finance_core/features/dashboard/daily_spending.dart';

void main() {
  final month = DateTime(2026, 11);
  Record tx(
    String id,
    String type,
    int amount, {
    String currency = 'VND',
    String category = 'normal',
  }) => Record(Entity.transactions, {
    'id': id,
    'type': type,
    'amount': amount,
    'currency': currency,
    'category_id': category,
    'account_id': 'cash',
    'occurred_at': '2026-11-01T00:00:00Z',
  });
  test(
    'reports only personal share, excludes reimbursements, preserves gross balance',
    () {
      final rows = [
        tx('bill', 'expense', 500000),
        tx('receipt', 'income', 200000, category: 'share'),
        tx('salary', 'income', 1000000),
        tx('normal', 'expense', 100000),
        tx('debt', 'expense', 200000),
      ];
      final bills = [
        Record(Entity.shareBills, {
          'id': 'b',
          'expense_tx_id': 'bill',
          'num_people': 5,
          'currency': 'VND',
          'status': 'completed',
        }),
      ];
      final payments = [
        Record(Entity.shareBillPayments, {
          'id': 'p',
          'share_bill_id': 'b',
          'income_tx_id': 'receipt',
          'amount': 200000,
        }),
      ];
      final reported = Ledger.reportingRows(
        rows,
        shareBills: bills,
        shareBillPayments: payments,
      );
      final totals = Ledger.monthly(reported, month, 'VND');
      expect(totals.income, 1000000);
      expect(totals.expense, 600000);
      expect(dailySpending(reported, month, 'VND')[0], 600000);
      expect(
        Ledger.balance(
          Record(Entity.accounts, {'id': 'cash', 'opening_balance': 0}),
          rows,
        ),
        400000,
      );
      expect(rows.first.money('amount'), 500000);
    },
  );
  test('no receipt means full personal expense regardless of people count', () {
    final rows = [
      tx('bill', 'expense', 100000),
      tx('tag-only', 'expense', 90000),
      tx('unlinked-share', 'income', 50000, category: 'share'),
      tx('usd', 'expense', 10000, currency: 'USD'),
    ];
    final projected = Ledger.reportingRows(
      rows,
      shareBills: [
        Record(Entity.shareBills, {
          'expense_tx_id': 'bill',
          'num_people': 3,
          'currency': 'VND',
        }),
        Record(Entity.shareBills, {
          'expense_tx_id': 'usd',
          'num_people': 3,
          'currency': 'USD',
        }),
      ],
      categories: [
        Record(Entity.categories, {
          'id': 'share',
          'name': 'Nhận share bill',
          'type': 'income',
        }),
      ],
    );
    expect(Ledger.monthly(projected, month, 'VND').expense, 190000);
    expect(Ledger.monthly(projected, month, 'VND').income, 0);
    expect(Ledger.monthly(projected, month, 'USD').expense, 10000);
  });
  test(
    'unequal, cross-month, edited and deleted receipts change bill cost by actual amounts',
    () {
      final expense = tx('expense', 'expense', 500000);
      final bill = Record(Entity.shareBills, {
        'id': 'b',
        'expense_tx_id': expense.id,
        'num_people': 5,
        'currency': 'VND',
      });
      Record receipt(String id, int amount, {bool deleted = false}) =>
          Record(Entity.shareBillPayments, {
            'id': id,
            'share_bill_id': 'b',
            'income_tx_id': 'income-$id',
            'amount': amount,
            'paid_at': '2026-12-01',
            'deleted_at': deleted ? '2026-12-02' : null,
            'people_count': 2,
          });
      int cost(List<Record> receipts) => Ledger.monthly(
        Ledger.reportingRows(
          [expense],
          shareBills: [bill],
          shareBillPayments: receipts,
        ),
        month,
        'VND',
      ).expense;
      expect(cost([receipt('a', 70000), receipt('b', 130000)]), 300000);
      expect(cost([receipt('a', 100000), receipt('b', 130000)]), 270000);
      expect(
        cost([receipt('a', 100000, deleted: true), receipt('b', 130000)]),
        370000,
      );
      expect(cost([receipt('a', 600000)]), -100000);
      expect(expense.money('amount'), 500000);
    },
  );
  testWidgets(
    'negative net cost remains signed without a negative donut slice',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: financeTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const CategoryChart(
                    entries: [
                      MapEntry('Bill', -100000),
                      MapEntry('Other', 200000),
                    ],
                    currency: 'VND',
                  ),
                  SpendingChart(
                    days: [-100000, ...List.filled(29, 0)],
                    month: month,
                    currency: 'VND',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(find.text(Money.format(-100000, 'VND')), findsOneWidget);
      expect(find.textContaining('Cột xanh lá'), findsOneWidget);
    },
  );
}
