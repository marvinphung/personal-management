import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/components.dart';
import 'package:finance_core/app/theme.dart';
import 'package:finance_core/app/widgets.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/dashboard/dashboard_screen.dart';
import 'package:finance_core/features/debts/debt_screen.dart';
import 'package:finance_core/features/investments/investment_screen.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace, TestCurrency;

void main() {
  for (final palette in [AppThemeColors.light, AppThemeColors.dark]) {
    test(
      'muted text meets normal-text contrast on ${palette == AppThemeColors.light ? 'light' : 'dark'} surfaces',
      () {
        for (final bg in [
          palette.bgSurface,
          palette.bgCanvas,
          palette.bgElevated,
        ]) {
          final a = palette.textMuted.computeLuminance(),
              b = bg.computeLuminance();
          expect(
            ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05),
            greaterThanOrEqualTo(4.5),
          );
        }
      },
    );
  }
  testWidgets('negative summary retains a visible minus sign', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            balanceMinor: -1200000,
            incomeMinor: 0,
            expenseMinor: 1200000,
            currency: 'VND',
          ),
        ),
      ),
    );
    expect(find.text('-1,200,000 ₫'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'fullscreen form keeps save reachable above keyboard and scrolls to its final field',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FormDialog(
            title: 'Form',
            busy: false,
            save: () => saved = true,
            children: [
              for (var i = 0; i < 12; i++)
                TextField(
                  key: ValueKey('f$i'),
                  decoration: InputDecoration(labelText: 'Field $i'),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('f11')));
      await tester.pumpAndSettle();
      final keyboardTop = 844 - 300;
      expect(
        tester.getRect(find.byKey(const ValueKey('f11'))).bottom,
        lessThanOrEqualTo(keyboardTop),
      );
      expect(tester.getRect(find.text('Save')).bottom, lessThan(keyboardTop));
      await tester.tap(find.text('Save'));
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'overview, debt and investment fit A54 with larger text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = LocalDatabase.memory();
        final repo = FinanceRepository(db, 'u');
        final w = UserWorkspace(
          db,
          repo,
          SyncEngine(db, FakeRemote()..offline = true),
        );
        addTearDown(w.close);
        final expense = repo.create(Entity.categories, {
          'name': 'Đầu tư',
          'behavior': 'investment_expense',
        });
        final person = repo.create(Entity.people, {
          'name': 'Người liên quan tên dài',
        });
        await repo.saveBatch([expense, person]);
        await repo.save(
          repo.create(Entity.debts, {
            'person_id': person.id,
            'direction': 'lent',
            'principal_amount': 1200000,
            'started_at': DateTime.now().toIso8601String(),
          }),
        );
        await repo.save(
          repo.create(Entity.transactions, {
            'type': 'expense',
            'amount': 1000000,
            'category_id': expense.id,
            'account_id': (await _cash(repo)).id,
            'occurred_at': DateTime.now().toIso8601String(),
          }),
        );
        for (final screen in [
          const DashboardScreen(),
          const DebtScreen(),
          const InvestmentScreen(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                workspaceProvider.overrideWith(() => TestWorkspace(w)),
                currencyProvider.overrideWith(() => TestCurrency()),
              ],
              child: MaterialApp(
                theme: financeTheme(brightness),
                locale: const Locale('vi'),
                supportedLocales: const [Locale('vi'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(body: screen),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: screen.runtimeType.toString(),
          );
        }
      },
    );
  }
}

Future<Record> _cash(FinanceRepository repo) async {
  final row = repo.create(Entity.accounts, {'name': 'Cash'});
  await repo.save(row);
  return row;
}
