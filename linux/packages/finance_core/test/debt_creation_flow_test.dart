import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/debts/debt_screen.dart';
import 'package:finance_core/features/debts/debt_service.dart';
import 'package:finance_core/features/catalog/catalog_screen.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;

void main() {
  testWidgets(
    'empty people picker creates and selects each person inline; grouped amounts save exact linked loans',
    (tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = LocalDatabase.memory();
      final repo = FinanceRepository(db, 'test-user');
      final w = UserWorkspace(
        db,
        repo,
        SyncEngine(db, FakeRemote()..offline = true),
      );
      addTearDown(w.close);
      final cash = repo.create(Entity.accounts, {'name': 'Tiền mặt'});
      final category = repo.create(Entity.categories, {
        'name': 'Công nợ',
        'behavior': 'cong_no_expense',
      });
      await repo.saveBatch([cash, category]);
      await repo.save(
        repo.create(Entity.tags, {
          'name': 'chovay',
          'category_id': category.id,
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workspaceProvider.overrideWith(() => TestWorkspace(w))],
          child: MaterialApp(
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDebtForm(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      for (final sample in [
        ('chó tiến', '1200000', '1,200,000', 1200000),
        ('Nguyên Minh', '1000000', '1,000,000', 1000000),
      ]) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final amount = find.byKey(const ValueKey('debt-amount'));
        await tester.enterText(amount, sample.$2);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(amount).controller!.text, sample.$3);
        final person = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Người liên quan',
        );
        await tester.ensureVisible(person);
        await tester.tap(person);
        await tester.pumpAndSettle();
        await tester.tap(find.text('＋ Thêm người mới').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Tên'),
          sample.$1,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(CatalogForm),
            matching: find.text('Lưu'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(sample.$1), findsOneWidget);
        expect(tester.widget<TextField>(amount).controller!.text, sample.$3);
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        final personRow = (await db.list(
          Entity.people,
        )).singleWhere((p) => p.text('name') == sample.$1);
        final debt = (await db.list(
          Entity.debts,
        )).singleWhere((d) => d.text('person_id') == personRow.id);
        expect(debt.money('principal_amount'), sample.$4);
        expect(debt.text('direction'), 'lent');
        final transaction = await db.get(
          Entity.transactions,
          debt.text('linked_transaction_id'),
        );
        expect(transaction!.money('amount'), sample.$4);
        expect(transaction.data['account_id'], isNull);
        expect(transaction.text('category_id'), category.id);
        expect(tester.takeException(), isNull);
      }
      expect(await db.list(Entity.debts), hasLength(2));
      expect(
        (await db.list(
          Entity.transactions,
        )).fold<int>(0, (s, t) => s + t.money('amount')),
        2200000,
      );
      final debt = (await db.list(Entity.debts)).first;
      await DebtService(repo).repay(debt, 50000);
      final payment = (await db.list(Entity.debtPayments)).single;
      final repayment = await db.get(
        Entity.transactions,
        payment.text('linked_transaction_id'),
      );
      expect(repayment!.data['account_id'], isNull);
      expect(repayment.money('amount'), 50000);
      expect(repayment.text('type'), 'income');
    },
  );
}
