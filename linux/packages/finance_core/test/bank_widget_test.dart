import 'package:finance_core/app/app.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/app/router.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:finance_core/features/bank_import/bank_draft.dart';
import 'package:finance_core/features/bank_import/bank_draft_repository.dart';
import 'package:finance_core/features/bank_import/pending_bank_screen.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;
import 'language_test.dart' show session;

class FakeBankInbox extends BankDraftRepository {
  final List<BankDraft> rows = [];
  bool failFinish = false, open = false;
  int finished = 0;
  @override
  Future<List<BankDraft>> pending({int offset = 0}) async =>
      rows.skip(offset).take(100).toList();
  @override
  Future<int> count() async => rows.length;
  @override
  Future<Map<String, dynamic>> settings() async => {
    'access': false,
    'capture': false,
    'sources': <Map>[],
  };
  @override
  Future<void> finish(BankDraft draft, {required bool confirmed}) async {
    if (failFinish) throw Exception('disk unavailable');
    rows.removeWhere((d) => d.id == draft.id);
    finished++;
    events.add('changed');
  }

  @override
  Future<bool> consumeOpenPending() async {
    final value = open;
    open = false;
    return value;
  }
}

class SignedOutWorkspace extends WorkspaceController {
  final VoidCallback onBuild;
  SignedOutWorkspace(this.onBuild);
  @override
  Future<UserWorkspace?> build() async {
    onBuild();
    return null;
  }
}

void main() {
  late UserWorkspace workspace;
  late FakeBankInbox inbox;
  late BankDraft draft;
  setUp(() {
    final db = LocalDatabase.memory();
    workspace = UserWorkspace(
      db,
      FinanceRepository(db, 'user'),
      SyncEngine(db, FakeRemote()..offline = true),
    );
    inbox = FakeBankInbox();
    draft = BankDraft.fromMap({
      'id': 'draft',
      'owner': 'user',
      'fingerprint': 'f' * 64,
      'bankCode': 'mbbank',
      'amountMinor': 1999,
      'currency': 'USD',
      'currencyScale': 2,
      'direction': 'expense',
      'occurredAtMillis': 1790000000000,
      'occurredAtSource': 'notification_text',
      'descriptionCandidate': 'Google Service',
    });
    inbox.rows.add(draft);
  });
  tearDown(() async {
    await workspace.close();
    inbox.dispose();
  });
  Widget wrap(Widget child, {Locale locale = const Locale('en')}) =>
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
          bankDraftRepositoryProvider.overrideWithValue(inbox),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('vi')],
          home: Scaffold(body: child),
        ),
      );

  testWidgets(
    'native finish failure retains draft; retry keeps one exact USD transaction',
    (tester) async {
      final repo = workspace.repository;
      final account = repo.create(Entity.accounts, {
        'name': 'USD card',
        'currency': 'USD',
      });
      await repo.save(account);
      inbox.failFinish = true;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TransactionForm(
                  record: draft.toTransaction(repo, accountId: account.id),
                  bankDraft: draft,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Amount'))
            .controller!
            .text,
        '19.99',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Coffee',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Tags'), '#coffee');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(inbox.rows, hasLength(1));
      expect(await workspace.db.list(Entity.transactions), hasLength(1));
      inbox.failFinish = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(inbox.rows, isEmpty);
      final saved = (await workspace.db.list(Entity.transactions)).single;
      expect(saved.money('amount'), 1999);
      expect(saved.text('currency'), 'USD');
      expect(saved.text('description'), 'Coffee');
      expect(await workspace.db.list(Entity.tags), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'pending list updates immediately after ignore on narrow Vietnamese screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(const PendingBankScreen(), locale: const Locale('vi')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('19.99 USD'), findsOneWidget);
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();
      expect(find.text('Đã xử lý hết'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(await workspace.db.list(Entity.transactions), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets('cold and warm widget requests open the pending route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language.user': 'en'});
    final prefs = await SharedPreferences.getInstance();
    inbox.open = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
          bankDraftRepositoryProvider.overrideWithValue(inbox),
          preferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWithValue(session('user')),
        ],
        child: const FinanceApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PendingBankScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanceApp)),
    );
    container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    inbox.open = true;
    inbox.events.add('openPending');
    await tester.pumpAndSettle();
    expect(find.byType(PendingBankScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets(
    'signed-out startup still activates private inbox cleanup lifecycle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var builds = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workspaceProvider.overrideWith(
              () => SignedOutWorkspace(() => builds++),
            ),
            bankDraftRepositoryProvider.overrideWithValue(inbox),
            preferencesProvider.overrideWithValue(prefs),
            sessionProvider.overrideWithValue(null),
          ],
          child: const FinanceApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
