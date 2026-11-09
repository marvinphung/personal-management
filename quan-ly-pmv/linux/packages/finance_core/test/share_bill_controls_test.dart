import 'package:finance_core/features/bank_import/bank_draft_repository.dart';
import 'bank_widget_test.dart' show FakeBankInbox;
import 'package:finance_core/features/bank_import/bank_draft.dart';
import 'package:finance_core/features/bank_import/pmv_bien_dong_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'package:finance_core/features/share_bill/share_bill_controls.dart';
import 'package:finance_core/features/share_bill/share_bill_service.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace, TestCurrency;

void main() {
  testWidgets(
    'receipt control defaults to one person and supports plus/minus',
    (t) async {
      var enabled = false, people = 1;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) => ShareBillControls(
                income: true,
                enabled: enabled,
                people: people,
                onEnabled: (v) => set(() => enabled = v),
                onPeople: (v) => set(() => people = v),
                onBill: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(people, 1);
      expect(
        find.text('Chưa có Share Bill chưa hoàn tất cùng tiền tệ.'),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Tăng số người'));
      await t.pumpAndSettle();
      expect(people, 2);
      await t.tap(find.byTooltip('Giảm số người'));
      await t.pumpAndSettle();
      expect(people, 1);
      expect(
        t
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Giảm số người',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('editing linked expense restores people and keeps receipts', (
    t,
  ) async {
    final db = LocalDatabase.memory(), remote = FakeRemote()..offline = true;
    final repo = FinanceRepository(db, 'user');
    final w = UserWorkspace(db, repo, SyncEngine(db, remote));
    addTearDown(w.close);
    final a = repo.create(Entity.accounts, {'name': 'Cash'});
    final c = repo.create(Entity.categories, {
      'name': 'Food',
      'type': 'expense',
    });
    await repo.saveBatch([a, c]);
    final tx = repo.create(Entity.transactions, {
      'type': 'expense',
      'amount': 600000,
      'account_id': a.id,
      'category_id': c.id,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    await ShareBillService(
      repo,
    ).saveExpenseWithShareBill(transaction: tx, tags: [], numPeople: 3);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(w)),
          currencyProvider.overrideWith(() => TestCurrency()),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('vi')],
          home: Scaffold(body: TransactionForm(record: tx)),
        ),
      ),
    );
    await t.pumpAndSettle();
    final controls = t.widget<ShareBillControls>(
      find.byType(ShareBillControls),
    );
    expect(controls.enabled, isTrue);
    expect(controls.people, 3);
    expect(controls.linked, isTrue);
    expect(controls.paidPeople, 1);
    await t.ensureVisible(find.byTooltip('Tăng số người đã trả'));
    await t.tap(find.byTooltip('Tăng số người đã trả'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Giảm số người'));
    await t.tap(find.byTooltip('Giảm số người'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect((await db.list(Entity.shareBills)).single.money('num_people'), 2);
    expect(await db.list(Entity.shareBills), hasLength(1));
    expect((await db.list(Entity.shareBills)).single.money('num_paid'), 2);
  });
  testWidgets(
    'income switch filters currency and receipt editor restores represented people',
    (t) async {
      final db = LocalDatabase.memory(), remote = FakeRemote()..offline = true;
      final repo = FinanceRepository(db, 'user');
      final w = UserWorkspace(db, repo, SyncEngine(db, remote));
      addTearDown(w.close);
      final a = repo.create(Entity.accounts, {'name': 'VND cash'});
      final usd = repo.create(Entity.accounts, {
        'name': 'USD cash',
        'currency': 'USD',
      });
      final c = repo.create(Entity.categories, {
        'name': 'Nhận share bill',
        'type': 'income',
      });
      await repo.saveBatch([a, usd, c]);
      await repo.rememberSelections(a.id, c.id);
      Record tx(String type, int amount, Record account) =>
          repo.create(Entity.transactions, {
            'type': type,
            'amount': amount,
            'currency': account.text('currency'),
            'account_id': account.id,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
          });
      final service = ShareBillService(repo);
      await service.saveExpenseWithShareBill(
        transaction: tx('expense', 600000, a),
        tags: [],
        numPeople: 3,
      );
      await service.saveExpenseWithShareBill(
        transaction: tx('expense', 10000, usd),
        tags: [],
        numPeople: 3,
      );
      final bill = (await db.list(
        Entity.shareBills,
      )).singleWhere((b) => b.text('currency') == 'VND');
      final receipt = tx('income', 100000, a).patch({'category_id': c.id});
      Widget wrap(Widget child) => ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(w)),
          currencyProvider.overrideWith(() => TestCurrency()),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('vi')],
          home: Scaffold(body: child),
        ),
      );
      await t.pumpWidget(
        wrap(TransactionForm(initialType: 'income', initialCategory: c.id)),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(SwitchListTile));
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      var control = t.widget<ShareBillControls>(find.byType(ShareBillControls));
      expect(control.people, 1);
      expect(find.text('Danh mục'), findsNothing);
      expect(find.text('Thẻ (Tags)'), findsNothing);
      expect(control.bills.map((b) => b.id), [bill.id]);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await service.saveIncomeWithShareBillPayment(
        transaction: receipt,
        tags: [],
        shareBillId: bill.id,
        peopleCount: 2,
      );
      await t.pumpWidget(wrap(TransactionForm(record: receipt)));
      await t.pumpAndSettle();
      control = t.widget<ShareBillControls>(find.byType(ShareBillControls));
      expect(control.people, 2);
      expect(control.billId, bill.id);
      expect(control.enabled, isTrue);
      await t.ensureVisible(find.byTooltip('Giảm số người'));
      await t.tap(find.byTooltip('Giảm số người'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect((await db.get(Entity.shareBills, bill.id))!.money('num_paid'), 2);
      expect(await db.list(Entity.shareBillPayments), hasLength(1));
    },
  );
  testWidgets(
    'bank income Share Bill hides category and tags and brings picker forward',
    (t) async {
      final db = LocalDatabase.memory(), repo = FinanceRepository(db, 'user');
      final w = UserWorkspace(
        db,
        repo,
        SyncEngine(db, FakeRemote()..offline = true),
      );
      addTearDown(w.close);
      final a = repo.create(Entity.accounts, {'name': 'Cash'});
      final cat = repo.create(Entity.categories, {
        'name': 'Nhận share bill',
        'type': 'income',
      });
      await repo.saveBatch([a, cat]);
      final draft = BankDraft.fromMap({
        'id': 'compact',
        'owner': 'user',
        'fingerprint': 'compact',
        'bankCode': 'mbbank',
        'currency': 'VND',
        'currencyScale': 0,
        'direction': 'income',
        'amountMinor': 100000,
        'occurredAtMillis': DateTime.now().millisecondsSinceEpoch,
        'occurredAtSource': 'notification_post_time',
      });
      await t.pumpWidget(
        ProviderScope(
          overrides: [workspaceProvider.overrideWith(() => TestWorkspace(w))],
          child: MaterialApp(
            home: Scaffold(
              body: PmvClassifyForm(draft: draft, accountId: a.id),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Danh mục'), findsOneWidget);
      await t.ensureVisible(find.byType(SwitchListTile));
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(find.text('Danh mục'), findsNothing);
      expect(find.text('Tags'), findsNothing);
      expect(
        find.widgetWithText(TextField, 'Thêm tag mới (tuỳ chọn)'),
        findsNothing,
      );
      expect(
        t.widget<ShareBillControls>(find.byType(ShareBillControls)).enabled,
        isTrue,
      );
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(find.text('Danh mục'), findsOneWidget);
    },
  );
  testWidgets(
    'bank expense can create a two-person bill with scoped category and tag',
    (t) async {
      final db = LocalDatabase.memory(), repo = FinanceRepository(db, 'user');
      final w = UserWorkspace(
        db,
        repo,
        SyncEngine(db, FakeRemote()..offline = true),
      );
      addTearDown(w.close);
      final account = repo.create(Entity.accounts, {'name': 'Test cash'});
      final house = repo.create(Entity.categories, {
        'name': 'Home test',
        'type': 'expense',
      });
      final other = repo.create(Entity.categories, {
        'name': 'Other test',
        'type': 'expense',
      });
      final correct = repo.create(Entity.tags, {
        'name': 'testrent',
        'display_name': 'Rent test',
        'category_id': house.id,
      });
      final wrong = repo.create(Entity.tags, {
        'name': 'testrent',
        'display_name': 'Rent test',
        'category_id': other.id,
      });
      await repo.saveBatch([account, house, other, wrong, correct]);
      final draft = BankDraft.fromMap({
        'id': 'expense-ui',
        'owner': 'user',
        'fingerprint': 'expense-ui',
        'bankCode': 'mbbank',
        'currency': 'VND',
        'currencyScale': 0,
        'direction': 'expense',
        'amountMinor': 800000,
        'occurredAtMillis': DateTime.now().millisecondsSinceEpoch,
        'occurredAtSource': 'notification_post_time',
      });
      final inbox = FakeBankInbox()..rows.add(draft);
      addTearDown(inbox.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceProvider.overrideWith(() => TestWorkspace(w)),
            bankDraftRepositoryProvider.overrideWithValue(inbox),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PmvClassifyForm(draft: draft, accountId: account.id),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(SwitchListTile));
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(find.text('Danh mục'), findsOneWidget);
      expect(
        t.widget<ShareBillControls>(find.byType(ShareBillControls)).paidPeople,
        1,
      );
      await t.ensureVisible(find.byTooltip('Tăng số người'));
      await t.tap(find.byTooltip('Tăng số người'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Home test'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Home test'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.widgetWithText(FilterChip, '#Rent test'));
      await t.tap(find.widgetWithText(FilterChip, '#Rent test'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Xác nhận'));
      await t.tap(find.text('Xác nhận'));
      await t.pumpAndSettle();
      final bill = (await db.list(Entity.shareBills)).single;
      expect(bill.money('num_people'), 2);
      expect(bill.money('num_paid'), 1);
      final tx = (await db.list(Entity.transactions)).single;
      expect(tx.text('category_id'), house.id);
      expect(tx.money('amount'), 800000);
      expect(tx.data['bank_source'], isNotNull);
      expect(
        (await db.list(Entity.transactionTags)).single.text('tag_id'),
        correct.id,
      );
      expect(inbox.finished, 1);
    },
  );
}
