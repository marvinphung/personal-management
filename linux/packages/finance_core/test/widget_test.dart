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
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), '#coffee');
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
  testWidgets('editing retains tags that finish loading after accounts', (
    tester,
  ) async {
    final repo = workspace.repository;
    final account = repo.create(Entity.accounts, {'name': 'Cash'});
    final tag = repo.create(Entity.tags, {'name': 'coffee'});
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
