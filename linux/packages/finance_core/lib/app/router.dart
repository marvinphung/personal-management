import '../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/database/record.dart';
import '../features/auth/auth_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/debts/debt_screen.dart';
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
          GoRoute(path: '/debts', builder: (_, _) => const DebtScreen()),
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
const destinations = [
  ('/', 'Dashboard', Icons.dashboard_outlined),
  ('/transactions', 'Transactions', Icons.receipt_long_outlined),
  ('/accounts', 'Accounts', Icons.account_balance_wallet_outlined),
  ('/debts', 'Debts', Icons.handshake_outlined),
  ('/people', 'People', Icons.people_outline),
  ('/notes', 'Notes', Icons.notes_outlined),
  ('/categories', 'Categories', Icons.category_outlined),
  ('/tags', 'Tags', Icons.tag),
  ('/settings', 'Settings', Icons.settings_outlined),
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
        final title =
            destinations.where((d) => d.$1 == location).firstOrNull?.$2 ??
            context.tr('More');
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
              appBar: AppBar(
                title: Text(context.tr(title)),
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
                        label: Text(context.tr('Transaction')),
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
                              context.tr('Personal Finance'),
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
                      selectedIndex:
                          [
                            '/',
                            '/transactions',
                            '/debts',
                            '/notes',
                          ].contains(location)
                          ? [
                              '/',
                              '/transactions',
                              '/debts',
                              '/notes',
                            ].indexOf(location)
                          : 4,
                      onDestinationSelected: (i) => context.go(
                        ['/', '/transactions', '/debts', '/notes', '/more'][i],
                      ),
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.home_outlined),
                          label: context.tr('Home'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: context.tr('Transactions'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.handshake_outlined),
                          label: context.tr('Debts'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.notes),
                          label: context.tr('Notes'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.more_horiz),
                          label: context.tr('More'),
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
