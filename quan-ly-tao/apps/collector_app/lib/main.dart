import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/banks/bank_settings_tab.dart';
import 'features/device/device_tab.dart';
import 'features/status/status_tab.dart';
import 'features/users/users_tab.dart';

const _collectorStatusChannel = MethodChannel('app.quanlytao.collector/status');
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_apiBaseUrl.isNotEmpty) {
    await _collectorStatusChannel.invokeMethod<void>(
      'configureBackend',
      {'url': _apiBaseUrl},
    );
  }
  runApp(const ProviderScope(child: CollectorApp()));
}

class CollectorApp extends ConsumerWidget {
  const CollectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Quản lý Tao — Máy chủ',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50),
          brightness: Brightness.dark,
        ),
      ),
      home: const CollectorRootScreen(),
    );
  }
}

class CollectorRootScreen extends ConsumerWidget {
  const CollectorRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(currentAdminProvider);

    return adminAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => AdminLoginScreen(onLoginSuccess: () => ref.invalidate(currentAdminProvider)),
      data: (admin) {
        if (admin == null) {
          return AdminLoginScreen(onLoginSuccess: () => ref.invalidate(currentAdminProvider));
        }
        return const CollectorHomeScreen();
      },
    );
  }
}

class CollectorHomeScreen extends ConsumerStatefulWidget {
  const CollectorHomeScreen({super.key});

  @override
  ConsumerState<CollectorHomeScreen> createState() => _CollectorHomeScreenState();
}

class _CollectorHomeScreenState extends ConsumerState<CollectorHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final apiClient = ref.watch(collectorApiClientProvider);

    final tabs = [
      StatusTab(apiClient: apiClient),
      UsersTab(apiClient: apiClient),
      BankSettingsTab(apiClient: apiClient),
      DeviceTab(apiClient: apiClient),
    ];

    final titles = [
      'Trạng thái thu thập',
      'Quản lý người dùng',
      'Cấu hình ngân hàng',
      'Thiết bị & Chuyển giao',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất quyền quản trị không?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
                  ],
                ),
              );
              if (ok == true) {
                await apiClient.logout();
                ref.invalidate(currentAdminProvider);
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Trạng thái',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Người dùng',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Ngân hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_android_outlined),
            selectedIcon: Icon(Icons.phone_android),
            label: 'Thiết bị',
          ),
        ],
      ),
    );
  }
}
