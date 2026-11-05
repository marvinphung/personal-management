import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/features/dashboard/spending_chart.dart';
import 'package:finance_core/features/dashboard/category_chart.dart';

void main() {
  testWidgets('daily chart supports day selection and narrow layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SpendingChart(
              days: List.generate(31, (i) => i == 0 ? 45000 : 0),
              month: DateTime(2026, 1),
              currency: 'VND',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(find.textContaining('1/1/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('category chart renders legend and zero data safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryChart(
            entries: [MapEntry('Food', 45000), MapEntry('Travel', 55000)],
            currency: 'VND',
          ),
        ),
      ),
    );
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryChart(entries: [], currency: 'VND'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
