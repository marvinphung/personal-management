import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;

void main() {
  for (final sample in [
    ('expense', 'normal', 'Mua chung'),
    ('income', 'normal', 'Ăn uống'),
    ('expense', 'cong_no_expense', 'Mua chung'),
  ]) {
    testWidgets(
      '${sample.$1}/${sample.$2}: readable shared tag saves correct category and tag link',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
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
        final category = repo.create(Entity.categories, {
          'name': sample.$1 == 'income' ? 'Nhận share bill' : 'Ăn uống',
          'type': sample.$1,
          'behavior': sample.$2,
        });
        final shared = repo.create(Entity.tags, {
          'name': 'scopedsharedtest',
          'display_name': sample.$3,
          'category_id': category.id,
        });
        await repo.saveBatch([
          category,
          shared,
          repo.create(Entity.accounts, {'name': 'Cash'}),
          repo.create(Entity.people, {'name': 'Person'}),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [workspaceProvider.overrideWith(() => TestWorkspace(w))],
            child: MaterialApp(
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en'), Locale('vi')],
              home: Scaffold(
                body: TransactionForm(
                  initialCategory: category.id,
                  initialType: sample.$1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Amount'),
          '10000',
        );
        if (sample.$2 == 'cong_no_expense') {
          await tester.ensureVisible(
            find.widgetWithText(ChoiceChip, 'Cho vay'),
          );
          await tester.tap(find.widgetWithText(ChoiceChip, 'Cho vay'));
          await tester.pumpAndSettle();
          final person = find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String> &&
                w.decoration.labelText == 'Người liên quan',
          );
          await tester.ensureVisible(person);
          await tester.tap(person);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Person').last);
          await tester.pumpAndSettle();
        }
        final chip = find.widgetWithText(FilterChip, '#${sample.$3}');
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        final tx = (await db.list(Entity.transactions)).single;
        expect(tx.text('type'), sample.$1);
        expect(tx.money('amount'), 10000);
        expect(tx.text('category_id'), category.id);
        expect(
          (await db.list(Entity.transactionTags)).any(
            (l) =>
                l.text('transaction_id') == tx.id &&
                l.text('tag_id') == shared.id,
          ),
          isTrue,
        );
        if (sample.$2 == 'cong_no_expense') {
          expect(await db.list(Entity.debts), hasLength(1));
        }
      },
    );
  }
}
