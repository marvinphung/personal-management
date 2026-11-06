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
import '../features/calendar/calendar_screen.dart';
import '../features/calendar/calendar_settings.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/debts/debt_screen.dart';
import '../features/share_bill/share_bill_screen.dart';
import '../features/investments/investment_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/transactions/transaction_form.dart';
import '../features/transactions/transaction_screen.dart';
import 'providers.dart';
import 'language.dart';
import '../features/auth/auth_screen.dart';
import 'search.dart';
import 'settings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ref.watch(
    sessionProvider.select((session) => session != null),
  );
  final needsLanguage = ref.watch(
    languageProvider.select((value) => value == null),
  );
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (!signedIn) return state.uri.path == '/login' ? null : '/login';
      if (needsLanguage) {
        return state.uri.path == '/language' ? null : '/language';
      }
      return state.uri.path == '/language' || state.uri.path == '/login'
          ? '/'
          : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/language',
        builder: (_, _) => const LanguageWelcomeScreen(),
      ),
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
            path: '/share-bills',
            builder: (_, _) => const ShareBillScreen(),
          ),
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
  ('/share-bills', 'Share Bill', Icons.group_outlined),
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
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang khởi động…'),
            ],
          ),
        ),
      ),
      error: (_, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'Không thể mở dữ liệu tài chính.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(workspaceProvider),
                  icon: Icon(Icons.refresh),
                  label: Text('Thử lại'),
                ),
              ],
            ),
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
                          tooltip: context.tr('Tìm kiếm (Ctrl+K)'),
                          onPressed: () => showGlobalSearch(context),
                          icon: const Icon(Icons.search_outlined),
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
                      width: 240,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.savings_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('Quản lý PMV'),
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ],
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
                                    selectedTileColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.1),
                                  ),
                              ],
                            ),
                          ),
                          const SyncStatus(),
                        ],
                      ),
                    ),
                  if (desktop)
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  Expanded(child: child),
                ],
              ),
              floatingActionButton:
                  desktop || !['/', '/transactions'].contains(location)
                  ? null
                  : FloatingActionButton(
                      onPressed: () => showTransactionForm(context),
                      tooltip: context.tr('Giao dịch mới'),
                      child: const Icon(Icons.add_rounded),
                    ),
              bottomNavigationBar: desktop
                  ? null
                  : NavigationBar(
                      selectedIndex: currentTabIndex < 0 ? 3 : currentTabIndex,
                      onDestinationSelected: (i) => context.go(pmvTabs[i].$1),
                      // Chỉ icon — label ẩn; tooltip và semantics vẫn hoạt động
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      destinations: [
                        // Tab 0: Tổng quan
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          selectedIcon: const Icon(Icons.home_rounded),
                          label: context.tr('Tổng quan'),
                          tooltip: context.tr('Tổng quan'),
                        ),
                        // Tab 1: Thu chi
                        NavigationDestination(
                          icon: const Icon(Icons.receipt_long_outlined),
                          selectedIcon: const Icon(Icons.receipt_long_rounded),
                          label: context.tr('Thu chi'),
                          tooltip: context.tr('Thu chi'),
                        ),
                        // Tab 2: Biến động — badge với số thông báo chờ
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: bankCount > 0,
                            label: Text('$bankCount'),
                            child: const Icon(Icons.notifications_outlined),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: bankCount > 0,
                            label: Text('$bankCount'),
                            child: const Icon(Icons.notifications_rounded),
                          ),
                          label: context.tr('Biến động'),
                          tooltip: context.tr('Biến động ngân hàng'),
                        ),
                        // Tab 3: Cài đặt
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings_rounded),
                          label: context.tr('Cài đặt'),
                          tooltip: context.tr('Cài đặt'),
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
  Widget build(BuildContext context) {
    final items = destinations.where(
      (d) => [
        '/accounts',
        '/people',
        '/categories',
        '/tags',
        '/settings',
      ].contains(d.$1),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(d.$3, size: 20),
              ),
              title: Text(context.tr(d.$2)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => context.go(d.$1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const SyncStatus(),
      ],
    );
  }
}
