import 'package:finance_core/app/app.dart';
import 'package:finance_core/app/language.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/app/router.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/localization/translations.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:finance_core/features/catalog/catalog_screen.dart';
import 'package:finance_core/features/debts/debt_screen.dart';
import 'package:finance_core/features/notes/notes_screen.dart';
import 'package:finance_core/features/transactions/transaction_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_client/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;

UserDto session(String id) => UserDto(
  id: id,
  username: id,
  role: 'user',
  status: 'active',
  mustChangePassword: false,
  captureEnabled: true,
);

class TestSession extends Notifier<UserDto?> {
  @override
  UserDto? build() => session('a');
  void change(UserDto? value) => state = value;
}

final testSessionProvider = NotifierProvider<TestSession, UserDto?>(
  TestSession.new,
);

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      sessionProvider.overrideWith((ref) => ref.watch(testSessionProvider)),
    ],
  );

  test(
    'choice persists across restart and logout, isolated per account',
    () async {
      final first = container();
      expect(first.read(languageProvider), isNull);
      await first.read(languageProvider.notifier).set('vi');
      expect(first.read(localeProvider), const Locale('vi'));
      first.read(testSessionProvider.notifier).change(null);
      expect(first.read(languageProvider), isNull);
      first.read(testSessionProvider.notifier).change(session('b'));
      expect(first.read(languageProvider), isNull);
      await first.read(languageProvider.notifier).set('en');
      first.dispose();
      final restarted = container();
      addTearDown(restarted.dispose);
      expect(restarted.read(languageProvider), 'vi');
      restarted.read(testSessionProvider.notifier).change(session('b'));
      expect(restarted.read(languageProvider), 'en');
    },
  );

  test(
    'invalid stored locale requires a new choice and unsupported writes fail',
    () async {
      await prefs.setString('language.a', 'xx');
      final c = container();
      addTearDown(c.dispose);
      expect(c.read(languageProvider), isNull);
      await expectLater(
        c.read(languageProvider.notifier).set('xx'),
        throwsArgumentError,
      );
      expect(c.read(languageProvider), isNull);
    },
  );

  test('translations retain all interpolation placeholders', () {
    final placeholders = RegExp(r'\{\w+\}');
    for (final entry in vietnamese.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(
        placeholders.allMatches(entry.value).map((m) => m[0]).toSet(),
        placeholders.allMatches(entry.key).map((m) => m[0]).toSet(),
        reason: entry.key,
      );
    }
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'first login language gate and instant Settings switch at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = LocalDatabase.memory();
        final workspace = UserWorkspace(
          db,
          FinanceRepository(db, 'a'),
          SyncEngine(db, FakeRemote()),
        );
        final c = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            sessionProvider.overrideWith(
              (ref) => ref.watch(testSessionProvider),
            ),
            workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
          ],
        );
        addTearDown(() async {
          c.dispose();
          await workspace.close();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(container: c, child: const FinanceApp()),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Choose your language\nChọn ngôn ngữ'),
          findsOneWidget,
        );
        expect(
          c.read(routerProvider).routeInformationProvider.value.uri.path,
          '/language',
        );
        // Direct navigation must not bypass onboarding.
        c.read(routerProvider).go('/transactions');
        await tester.pumpAndSettle();
        expect(
          c.read(routerProvider).routeInformationProvider.value.uri.path,
          '/language',
        );
        await tester.tap(find.text('Tiếng Việt'));
        await tester.pump();
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(find.text('Thu nhập'), findsOneWidget);
        expect(find.text('Chi tiêu'), findsOneWidget);
        expect(prefs.getString('language.a'), 'vi');
        expect(tester.takeException(), isNull);
        c.read(routerProvider).go('/settings');
        await tester.pumpAndSettle();
        expect(find.text('Ngôn ngữ'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(find.text('Language'), findsOneWidget);
        expect(c.read(localeProvider), const Locale('en'));
        expect(
          c.read(routerProvider).routeInformationProvider.value.uri.path,
          '/settings',
        );
        expect(prefs.getString('language.a'), 'en');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('Vietnamese forms fit screen width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = LocalDatabase.memory();
      final workspace = UserWorkspace(
        db,
        FinanceRepository(db, 'a'),
        SyncEngine(db, FakeRemote()),
      );
      addTearDown(workspace.close);
      for (final form in [
        const CatalogForm(entity: Entity.accounts),
        const CatalogForm(entity: Entity.categories),
        const CatalogForm(entity: Entity.people),
        const DebtForm(),
        const NoteForm(),
        const TransactionForm(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesProvider.overrideWithValue(prefs),
              workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
            ],
            child: MaterialApp(
              locale: const Locale('vi'),
              supportedLocales: const [Locale('en'), Locale('vi')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(body: form),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lưu'), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: form.runtimeType.toString(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets(
    'Vietnamese expense form saves stable ledger values and original text',
    (tester) async {
      await prefs.setString('language.a', 'vi');
      final db = LocalDatabase.memory();
      final repo = FinanceRepository(db, 'a');
      final workspace = UserWorkspace(
        db,
        repo,
        SyncEngine(db, FakeRemote()..offline = true),
      );
      await repo.save(repo.create(Entity.accounts, {'name': 'My Cash'}));
      final c = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) => ref.watch(testSessionProvider)),
          workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await workspace.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const FinanceApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your language\nChọn ngôn ngữ'), findsNothing);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Giao dịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nhập số tiền'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '45k');
      await tester.enterText(
        find.widgetWithText(TextField, 'Mô tả'),
        'Coffee with Nam',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      final saved = (await db.list(Entity.transactions)).single;
      expect(saved.text('type'), 'expense');
      expect(saved.text('description'), 'Coffee with Nam');
      expect(saved.money('amount'), 45000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
