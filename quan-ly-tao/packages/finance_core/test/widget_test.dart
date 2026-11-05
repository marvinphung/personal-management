import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/app/theme.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'package:finance_core/features/dashboard/dashboard_screen.dart';
import 'package:finance_core/features/notes/notes_screen.dart';
import 'repository_test.dart' show FakeRemote;

class TestWorkspace extends WorkspaceController {
  final UserWorkspace workspace;
  TestWorkspace(this.workspace);
  @override
  Future<UserWorkspace?> build() async => workspace;
}

void main() {
  late UserWorkspace workspace;
  setUp(() {
    final db = LocalDatabase.memory();
    workspace = UserWorkspace(
      db,
      FinanceRepository(db, 'user'),
      SyncEngine(db, FakeRemote()..offline = true),
    );
  });
  tearDown(() async {
    await workspace.close();
  });
  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
      currencyProvider.overrideWith(() => TestCurrency()),
    ],
    child: MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('vi')],
      theme: financeTheme(Brightness.light),
      home: Scaffold(body: child),
    ),
  );
  testWidgets('quick expense form focuses amount and saves offline with tags', (
    tester,
  ) async {
    final repo = workspace.repository;
    await repo.save(repo.create(Entity.accounts, {'name': 'MB Bank'}));
    await repo.save(
      repo.create(Entity.categories, {'name': 'Food', 'type': 'expense'}),
    );
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTransactionForm(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextField, 'Amount');
    expect(tester.widget<TextField>(amount).autofocus, true);
    await tester.enterText(amount, '45k');
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Coffee',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Add tags (optional)'),
      '#coffee',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await workspace.db.list(Entity.transactions)).single;
    expect(saved.money('amount'), 45000);
    expect(saved.text('description'), 'Coffee');
    expect(
      (await workspace.db.list(Entity.tags)).single.text('name'),
      'coffee',
    );
    expect(await workspace.db.pending(), isNotEmpty);
  });
  testWidgets(
    'installment form asks monthly payment and creates six dated expenses',
    (tester) async {
      final repo = workspace.repository;
      await repo.save(repo.create(Entity.accounts, {'name': 'Cash'}));
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTransactionForm(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Installments'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Monthly payment'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Monthly payment'),
        '100k',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final rows = await workspace.db.list(Entity.transactions);
      expect(rows, hasLength(6));
      expect(
        rows.every(
          (r) => r.money('amount') == 100000 && r.date('occurred_at').day == 24,
        ),
        true,
      );
      expect(
        rows.map((r) => r.text('installment_group')).toSet(),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'category chips select tags without typing and reset on category change',
    (tester) async {
      final repo = workspace.repository;
      final food = repo.create(Entity.categories, {'name': 'Ăn uống'});
      final travel = repo.create(Entity.categories, {'name': 'Đi lại'});
      await repo.saveBatch([
        food,
        travel,
        repo.create(Entity.accounts, {'name': 'Cash'}),
      ]);
      await repo.saveBatch([
        repo.create(Entity.tags, {'name': 'caphe', 'category_id': food.id}),
        repo.create(Entity.tags, {'name': 'xangxe', 'category_id': travel.id}),
      ]);
      await tester.pumpWidget(wrap(const TransactionForm()));
      await tester.pumpAndSettle();
      final picker = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Category',
      );
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, '#caphe'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#xangxe'), findsNothing);
      await tester.ensureVisible(find.text('#caphe'));
      await tester.tap(find.text('#caphe'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '#caphe'))
            .selected,
        true,
      );
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đi lại').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, '#caphe'), findsNothing);
      await tester.ensureVisible(find.text('#xangxe'));
      await tester.tap(find.text('#xangxe'));
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '50k');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final tx = (await workspace.db.list(Entity.transactions)).single;
      expect(tx.text('category_id'), travel.id);
      final links = await workspace.db.list(Entity.transactionTags);
      expect(links, hasLength(1));
      final tag = await workspace.db.get(
        Entity.tags,
        links.single.text('tag_id'),
      );
      expect(tag!.text('name'), 'xangxe');
    },
  );
  testWidgets(
    'Cho vay requires a borrower and creates a debt instead of spending',
    (tester) async {
      final repo = workspace.repository;
      final category = repo.create(Entity.categories, {'name': 'Cho vay'});
      final person = repo.create(Entity.people, {'name': 'Nam'});
      await repo.saveBatch([
        category,
        person,
        repo.create(Entity.accounts, {'name': 'MB Bank'}),
      ]);
      await tester.pumpWidget(wrap(const TransactionForm()));
      await tester.pumpAndSettle();
      expect(find.text('Borrower'), findsOneWidget);
      expect(find.text('Installments'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '1m');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Create or select a person first'), findsOneWidget);
      expect(await workspace.db.list(Entity.transactions), isEmpty);
      final picker = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Borrower',
      );
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nam').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final tx = (await workspace.db.list(Entity.transactions)).single;
      final debt = (await workspace.db.list(Entity.debts)).single;
      expect(tx.text('purpose'), 'debt_disbursement');
      expect(debt.text('linked_transaction_id'), tx.id);
      expect(debt.text('person_id'), person.id);
    },
  );
  testWidgets('editing retains tags that finish loading after accounts', (
    tester,
  ) async {
    final repo = workspace.repository;
    final account = repo.create(Entity.accounts, {'name': 'Cash'});
    final category = repo.create(Entity.categories, {'name': 'Ăn uống'});
    await repo.save(category);
    final tag = repo.create(Entity.tags, {
      'name': 'coffee',
      'category_id': category.id,
    });
    await repo.save(account);
    final transaction = repo.create(Entity.transactions, {
      'type': 'expense',
      'amount': 45000,
      'account_id': account.id,
      'description': 'Coffee',
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    await repo.saveTransaction(transaction, [tag]);
    final delayed = Completer<List<Record>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
          recordsProvider(Entity.tags).overrideWith((ref) => delayed.future),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('vi')],
          home: Scaffold(body: TransactionForm(record: transaction)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    delayed.complete([tag]);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '#coffee'))
          .selected,
      true,
    );
  });
  testWidgets('invalid amount stays on form with understandable error', (
    tester,
  ) async {
    await workspace.repository.save(
      workspace.repository.create(Entity.accounts, {'name': 'Cash'}),
    );
    await tester.pumpWidget(wrap(const TransactionForm()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter an amount'), findsOneWidget);
    expect(await workspace.db.list(Entity.transactions), isEmpty);
  });
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('monthly dashboard renders without overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const DashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('note form saves a pinned plain text note', (tester) async {
    await tester.pumpWidget(wrap(const NoteForm()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Tuition deadline',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note'),
      'Pay before October 10',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final note = (await workspace.db.list(Entity.notes)).single;
    expect(note.flag('is_pinned'), true);
    expect(note.text('title'), 'Tuition deadline');
  });
}

class TestCurrency extends CurrencyController {
  @override
  String build() => 'VND';
}
