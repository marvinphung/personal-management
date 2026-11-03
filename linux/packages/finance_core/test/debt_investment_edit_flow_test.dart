import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/debts/debt_screen.dart';
import 'package:finance_core/features/investments/investment_screen.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;

void main() {
  for (final investment in [false, true]) {
    testWidgets(
      '${investment ? 'investment' : 'debt'} create/edit preserve dates and exact amounts without exclusion controls',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = LocalDatabase.memory();
        final repo = FinanceRepository(db, 'u');
        final w = UserWorkspace(
          db,
          repo,
          SyncEngine(db, FakeRemote()..offline = true),
        );
        addTearDown(w.close);
        final person = repo.create(Entity.people, {'name': 'Test person'});
        final category = repo.create(Entity.categories, {
          'name': investment ? 'Đầu tư' : 'Công nợ',
          'type': 'expense',
          'behavior': investment ? 'investment_expense' : 'cong_no_expense',
        });
        await repo.saveBatch([
          person,
          category,
          repo.create(Entity.accounts, {'name': 'Cash'}),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesProvider.overrideWithValue(prefs),
              workspaceProvider.overrideWith(() => TestWorkspace(w)),
            ],
            child: MaterialApp(
              locale: const Locale('vi'),
              supportedLocales: const [Locale('vi'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(
                body: investment
                    ? const InvestmentScreen()
                    : Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showDebtForm(context),
                          child: const Text('Create debt'),
                        ),
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(investment ? 'Thêm giao dịch đầu tư' : 'Create debt'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '1000000');
        if (!investment) {
          final personPicker = find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String> &&
                w.decoration.labelText == 'Người liên quan',
          );
          await tester.ensureVisible(personPicker);
          await tester.tap(personPicker);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Test person').last);
          await tester.pumpAndSettle();
        }
        expect(find.text('Không tính vào tổng thu/chi'), findsNothing);
        if (!investment) {
          await tester.ensureVisible(find.text('Ngày giao dịch').last);
          await tester.tap(find.text('Ngày giao dịch').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.edit_outlined).last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextField),
            ),
            '31/01/2024',
          );
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(find.byType(TransactionForm), findsNothing);
        var movement = (await db.list(Entity.transactions)).single;
        expect(movement.flag('exclude_from_totals'), isFalse);
        expect(movement.money('amount'), 1000000);
        if (!investment) expect(movement.date('occurred_at').day, 31);
        if (investment) {
          await tester.tap(find.text('Chi đầu tư'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sửa'));
        } else {
          final d = (await db.list(Entity.debts)).single;
          final context = tester.element(find.text('Create debt'));
          showDebtDetail(context, d);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chỉnh sửa'));
        }
        await tester.pumpAndSettle();
        final amount = find.byType(TextField).first;
        expect(tester.widget<TextField>(amount).controller!.text, '1,000,000');
        await tester.enterText(amount, '1200000');
        expect(find.text('Không tính vào tổng thu/chi'), findsNothing);
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        movement = (await db.list(Entity.transactions)).single;
        expect(movement.money('amount'), 1200000);
        expect(movement.flag('exclude_from_totals'), isFalse);
        if (!investment) {
          final d = (await db.list(Entity.debts)).single;
          expect(d.money('principal_amount'), 1200000);
          expect(d.date('started_at'), movement.date('occurred_at'));
          expect(d.date('started_at').year, 2024);
          expect(d.flag('exclude_from_totals'), isFalse);
        }
      },
    );
  }
}
