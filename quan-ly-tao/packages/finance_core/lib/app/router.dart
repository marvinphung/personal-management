import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/database/record.dart';
import '../core/localization/app_language.dart';
import '../features/auth/auth_screen.dart';
import '../features/bank_import/bank_providers.dart';
import '../features/bank_import/pending_bank_screen.dart';
import '../features/banks/bank_list.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/debts/debt_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/transactions/transaction_form.dart';
import '../features/transactions/transaction_screen.dart';
import 'language.dart';
import 'providers.dart';
import 'search.dart';
import 'settings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ref.watch(
    sessionProvider.select((s) => s != null && s.status == 'active' && !s.mustChangePassword),
  );
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
          GoRoute(
            path: '/pending',
            builder: (_, _) => const PendingBankScreen(),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/settings/banks', builder: (_, _) => const BankListScreen()),
          GoRoute(path: '/settings/widget', builder: (_, _) => const WidgetSettingsScreen()),
          GoRoute(path: '/debts', builder: (_, _) => const DebtScreen()),
          GoRoute(path: '/notes', builder: (_, _) => const NotesScreen()),
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

const destinations = [
  ('/', 'Tổng quan', Icons.dashboard_outlined),
  ('/transactions', 'Thu chi', Icons.receipt_long_outlined),
  ('/pending', 'Biến động', Icons.notifications_outlined),
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
              Text(context.tr('Không thể mở dữ liệu cục bộ.')),
              TextButton(
                onPressed: () => ref.invalidate(workspaceProvider),
                child: Text(context.tr('Thử lại')),
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
        final title = destinations.where((d) => d.$1 == location).firstOrNull?.$2 ??
            (location == '/pending'
                ? 'Biến động số dư'
                : location.startsWith('/settings/banks')
                    ? 'Ngân hàng liên kết'
                    : 'Quản lý Tao');

        final pendingCount = ref.watch(bankCountProvider).value ?? 0;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                showTransactionForm(context, defaultType: 'expense'),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                showGlobalSearch(context),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                showGlobalSearch(context),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  IconButton(
                    tooltip: 'Tìm kiếm (Ctrl+K)',
                    onPressed: () => showGlobalSearch(context),
                    icon: const Icon(Icons.search),
                  ),
                  if (desktop) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B873F)),
                      onPressed: () => showTransactionForm(context, defaultType: 'income'),
                      icon: const Icon(Icons.add),
                      label: const Text('+ Thu'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                      onPressed: () => showTransactionForm(context, defaultType: 'expense'),
                      icon: const Icon(Icons.remove),
                      label: const Text('+ Chi'),
                    ),
                    const SizedBox(width: 16),
                  ],
                ],
              ),
              body: Row(
                children: [
                  if (desktop)
                    SizedBox(
                      width: 230,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Quản lý Tao',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              children: [
                                for (final d in destinations)
                                  ListTile(
                                    selected: location == d.$1,
                                    leading: d.$1 == '/pending'
                                        ? Badge(
                                            label: Text('$pendingCount'),
                                            isLabelVisible: pendingCount > 0,
                                            child: Icon(d.$3),
                                          )
                                        : Icon(d.$3),
                                    title: Text(d.$2),
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
              floatingActionButton: desktop
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => showTransactionForm(context),
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('Transaction')),
                    ),
              bottomNavigationBar: desktop
                  ? null
                  : NavigationBar(
                      selectedIndex: [
                        '/',
                        '/transactions',
                        '/pending',
                        '/settings',
                      ].contains(location)
                          ? [
                              '/',
                              '/transactions',
                              '/pending',
                              '/settings',
                            ].indexOf(location)
                          : (location.startsWith('/settings') ? 3 : 0),
                      onDestinationSelected: (i) => context.go(
                        ['/', '/transactions', '/pending', '/settings'][i],
                      ),
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: 'Tổng quan',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'Thu chi',
                        ),
                        NavigationDestination(
                          icon: Badge(
                            label: Text('$pendingCount'),
                            isLabelVisible: pendingCount > 0,
                            child: const Icon(Icons.notifications_outlined),
                          ),
                          selectedIcon: Badge(
                            label: Text('$pendingCount'),
                            isLabelVisible: pendingCount > 0,
                            child: const Icon(Icons.notifications),
                          ),
                          label: 'Biến động',
                        ),
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
