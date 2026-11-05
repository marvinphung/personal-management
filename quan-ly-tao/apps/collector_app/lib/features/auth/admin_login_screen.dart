import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final collectorSessionStoreProvider = Provider<SessionStore>((ref) {
  return CollectorSecureSessionStore();
});

/// Keeps the administrator session across process restarts without sharing it
/// with the user-facing app. Android stores the value encrypted through the
/// device keystore; it is removed only on an explicit logout (or if the server
/// rejects an expired/revoked session).
class CollectorSecureSessionStore implements SessionStore {
  static const _tokenKey = 'qlt_collector_admin_session_token';

  final FlutterSecureStorage _storage;

  CollectorSecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);
}

final collectorApiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/v1');
});

final collectorApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(collectorApiBaseUrlProvider),
    sessionStore: ref.watch(collectorSessionStoreProvider),
  );
});

final currentAdminProvider = FutureProvider<UserDto?>((ref) async {
  final api = ref.watch(collectorApiClientProvider);
  final token = await ref.watch(collectorSessionStoreProvider).getToken();
  if (token == null) return null;
  try {
    final user = await api.getMe();
    if (user.role != 'admin') {
      await api.logout();
      return null;
    }
    return user;
  } catch (_) {
    return null;
  }
});

class AdminLoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;
  const AdminLoginScreen({super.key, required this.onLoginSuccess});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = ref.read(collectorApiClientProvider);

    try {
      final authResp = await api.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (authResp.user.role != 'admin') {
        await api.logout();
        if (mounted) {
          setState(() {
            _errorMessage = 'Tài khoản không có quyền quản trị viên máy chủ.';
          });
        }
        return;
      }
      ref.invalidate(currentAdminProvider);
      widget.onLoginSuccess();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể kết nối đến máy chủ.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tao — Đăng nhập Máy chủ'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 64, color: Color(0xFF006C50)),
                  const SizedBox(height: 16),
                  Text(
                    'Đăng nhập Quản trị viên',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên quản trị viên',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng nhập quản trị'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
