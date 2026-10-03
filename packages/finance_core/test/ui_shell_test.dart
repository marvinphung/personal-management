import 'package:finance_core/app/router.dart';
import 'package:finance_core/app/theme.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    await initializeDateFormatting('en');
  });
  test('Destinations contain four tabs with Vietnamese labels', () {
    expect(destinations.length, 4);
    expect(destinations[0].$2, 'Tổng quan');
    expect(destinations[1].$2, 'Thu chi');
    expect(destinations[2].$2, 'Biến động');
    expect(destinations[3].$2, 'Cài đặt');

    // Verify paths
    expect(destinations[0].$1, '/');
    expect(destinations[1].$1, '/transactions');
    expect(destinations[2].$1, '/pending');
    expect(destinations[3].$1, '/settings');
  });

  test('Finance theme supports light and dark modes with semantic colors', () {
    final light = financeTheme(Brightness.light);
    final dark = financeTheme(Brightness.dark);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(kIncomeColor, const Color(0xFF1B873F));
    expect(kExpenseColor, const Color(0xFFD32F2F));
  });

  testWidgets('TransactionForm shows read-only banner and disables amount for bank transactions', (tester) async {
    final bankTx = Record(Entity.transactions, {
      'id': 'tx-123',
      'source': 'bank',
      'amount': 720000,
      'currency': 'VND',
      'type': 'income',
      'occurred_at': '2026-10-03T12:00:00Z',
      'description': 'BIDV NHAN TIEN',
      'note': '',
      'category_id': null,
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('vi'), Locale('en')],
          locale: const Locale('vi'),
          home: Scaffold(
            body: TransactionForm(record: bankTx),
          ),
        ),
      ),
    );

    // Verify bank immutability notice is displayed
    expect(find.textContaining('Giao dịch ngân hàng'), findsOneWidget);

    // Verify amount TextField is read-only
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.readOnly, true);
  });
}
