import 'package:flutter/foundation.dart';
import '../features/bank_import/bank_draft_repository.dart';
import '../features/bank_import/bank_providers.dart';
import '../features/bank_import/pmv_bien_dong_screen.dart';
import '../features/bank_import/bank_import_settings.dart';
import '../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/database/record.dart';
import '../features/auth/auth_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/calendar/calendar_settings.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/debts/debt_screen.dart';
import '../features/investments/investment_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/transactions/transaction_form.dart';
import '../features/transactions/transaction_screen.dart';
import 'providers.dart';
import 'language.dart';
import 'search.dart';
import 'settings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ref.watch(sessionProvider.select((s) => s != null));
  final needsLanguage = ref.watch(
    languageProvider.select((value) => value == null),
  );
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) => !signedIn
        ? state.uri.path == '/login'
              ? null
              : '/login'
        : needsLanguage
        ? state.uri.path == '/language'
              ? null
              : '/language'
        : (state.uri.path == '/login' || state.uri.path == '/language')
        ? '/'
        : null,
    routes: [
      GoRoute(
        path: '/language',
        builder: (_, _) => const LanguageWelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            FinanceShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: '/transactions',
            builder: (_, _) => const TransactionScreen(),
          ),
          if (BankDraftRepository.supported) ...[
            GoRoute(
              path: '/transactions/pending',
              builder: (_, _) => const PmvBienDongScreen(),
            ),
            GoRoute(
              path: '/settings/bank-import',
              builder: (_, _) => const BankImportSettings(),
            ),
            if (kDebugMode)
              GoRoute(
                path: '/settings/bank-import/parser',
                builder: (_, _) => const BankParserScreen(),
              ),
          ],
          GoRoute(path: '/debts', builder: (_, _) => const DebtScreen()),
          GoRoute(
            path: '/investments',
            builder: (_, _) => const InvestmentScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (_, state) => CalendarScreen(
              initialDate: state.uri.queryParameters['date'] != null
                  ? DateTime.tryParse(state.uri.queryParameters['date']!)
                  : null,
            ),
          ),
          GoRoute(
            path: '/calendar/settings',
            builder: (_, _) => const CalendarSettings(),
          ),
          GoRoute(path: '/notes', builder: (_, _) => const NotesScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
          for (final entity in [
            Entity.accounts,
            Entity.categories,
            Entity.tags,
            Entity.people,
          ])
            GoRoute(
              path: '/${entity.name}',
              builder: (_, _) => CatalogScreen(entity: entity),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Primary 4-tab destinations shown in the bottom NavigationBar.
const pmvTabs = [
  ('/', 'Tổng quan', Icons.home_outlined),
  ('/transactions', 'Thu chi', Icons.receipt_long_outlined),
  ('/transactions/pending', 'Biến động', Icons.notifications_active_outlined),
  ('/settings', 'Cài đặt', Icons.settings_outlined),
];

/// All routable destinations (used for desktop side-rail lookup).
const destinations = [
  ('/', 'Tổng quan', Icons.home_outlined),
  ('/transactions', 'Thu chi', Icons.receipt_long_outlined),
  ('/transactions/pending', 'Biến động', Icons.notifications_active_outlined),
  ('/debts', 'Công nợ', Icons.handshake_outlined),
  ('/investments', 'Đầu tư', Icons.trending_up),
  ('/calendar', 'Lịch', Icons.calendar_month_outlined),
  ('/notes', 'Ghi chú', Icons.notes_outlined),
  ('/categories', 'Danh mục', Icons.category_outlined),
  ('/tags', 'Thẻ', Icons.tag),
  ('/settings', 'Cài đặt', Icons.settings_outlined),
];

class FinanceShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const FinanceShell({super.key, required this.location, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    return workspace.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('Could not open your local finance data.')),
              TextButton(
                onPressed: () => ref.invalidate(workspaceProvider),
                child: Text(context.tr('Retry')),
              ),
            ],
          ),
        ),
      ),
      data: (w) {
        if (w == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final desktop = MediaQuery.sizeOf(context).width >= 850;
        // Determine current title from tab list; fall back to route-based label.
        final tabTitle =
            pmvTabs.where((d) => d.$1 == location).firstOrNull?.$2 ??
            destinations.where((d) => d.$1 == location).firstOrNull?.$2 ??
            (location == '/transactions/pending'
                ? 'Biến động'
                : location.startsWith('/settings/bank-import')
                ? 'Ngân hàng import'
                : location);

        // Map current location to tab index (−1 = not a primary tab).
        final tabPaths = pmvTabs.map((t) => t.$1).toList();
        // "/transactions/pending" also matches tab index 2.
        int currentTabIndex = tabPaths.indexOf(location);
        if (currentTabIndex < 0 && location == '/transactions/pending') {
          currentTabIndex = 2;
        }

        final bankCount = ref.watch(bankCountProvider).value ?? 0;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                showTransactionForm(context),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                showGlobalSearch(context),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                showGlobalSearch(context),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar:
                  location.startsWith('/calendar') || location == '/investments'
                  ? null
                  : AppBar(
                      title: Text(context.tr(tabTitle)),
                      actions: [
                        IconButton(
                          tooltip: context.tr('Search (Ctrl+K)'),
                          onPressed: () => showGlobalSearch(context),
                          icon: const Icon(Icons.search),
                        ),
                        if (desktop)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: FilledButton.icon(
                              onPressed: () => showTransactionForm(context),
                              icon: const Icon(Icons.add),
                              label: Text(context.tr('Giao dịch')),
                            ),
                          ),
                      ],
                    ),
              body: Row(
                children: [
                  if (desktop)
                    SizedBox(
                      width: 225,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              context.tr('Quản lý PMV'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final d in destinations)
                                  ListTile(
                                    selected: location == d.$1,
                                    leading: Icon(d.$3),
                                    title: Text(context.tr(d.$2)),
                                    onTap: () => context.go(d.$1),
                                  ),
                              ],
                            ),
                          ),
                          const SyncStatus(),
                        ],
                      ),
                    ),
                  if (desktop) const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              ),
              floatingActionButton:
                  desktop || !['/', '/transactions'].contains(location)
                  ? null
                  : FloatingActionButton(
                      onPressed: () => showTransactionForm(context),
                      tooltip: context.tr('Giao dịch mới'),
                      child: const Icon(Icons.add),
                    ),
              bottomNavigationBar: desktop
                  ? null
                  : NavigationBar(
                      selectedIndex: currentTabIndex < 0 ? 3 : currentTabIndex,
                      onDestinationSelected: (i) => context.go(pmvTabs[i].$1),
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      destinations: [
                        // Tab 0: Tổng quan
                        const NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Tổng quan',
                        ),
                        // Tab 1: Thu chi
                        const NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'Thu chi',
                        ),
                        // Tab 2: Biến động — badge with pending bank draft count.
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: bankCount > 0,
                            label: Text('$bankCount'),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: bankCount > 0,
                            label: Text('$bankCount'),
                            child: const Icon(Icons.notifications_active),
                          ),
                          label: 'Biến động',
                        ),
                        // Tab 3: Cài đặt
                        const NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: 'Cài đặt',
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final d in destinations.where(
        (d) => [
          '/accounts',
          '/people',
          '/categories',
          '/tags',
          '/settings',
        ].contains(d.$1),
      ))
        ListTile(
          leading: Icon(d.$3),
          title: Text(context.tr(d.$2)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(d.$1),
        ),
      const SyncStatus(),
    ],
  );
}
