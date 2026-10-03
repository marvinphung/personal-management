import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final auth = ref.read(authRepositoryProvider);

    try {
      if (_isSignUp) {
        final res = await auth.signUp(
          _usernameController.text.trim(),
          _passwordController.text,
        );
        if (mounted) {
          setState(() {
            _isSignUp = false;
            _successMessage = res.message;
          });
        }
      } else {
        await auth.signIn(
          _usernameController.text.trim(),
          _passwordController.text,
        );
        ref.invalidate(currentUserProvider);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể kết nối đến máy chủ. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeTemporaryPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = ref.read(authRepositoryProvider);

    try {
      await auth.changePassword(
        _oldPasswordController.text,
        _passwordController.text,
      );
      ref.invalidate(currentUserProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Lỗi đổi mật khẩu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user != null) {
      if (user.status == 'pending') {
        return _buildPendingApprovalScreen(user);
      }
      if (user.mustChangePassword) {
        return _buildChangeTemporaryPasswordScreen(user);
      }
    }
    return _buildAuthForm();
  }

  Widget _buildPendingApprovalScreen(UserDto user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Tao'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(currentUserProvider);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Tài khoản đang chờ duyệt',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Chào ${user.username}, tài khoản của bạn đang chờ quản trị viên phê duyệt trước khi sử dụng.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Kiểm tra trạng thái'),
                onPressed: () {
                  ref.invalidate(currentUserProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeTemporaryPasswordScreen(UserDto user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu bắt buộc'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bạn đang sử dụng mật khẩu tạm thời. Vui lòng nhập mật khẩu tạm và thiết lập mật khẩu mới.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu tạm thời',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu tạm thời' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới (tối thiểu 8 ký tự)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'Mật khẩu phải từ 8 ký tự' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Mật khẩu xác nhận không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _changeTemporaryPassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu mật khẩu mới'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Scaffold(
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
                  Text(
                    'Quản lý Tao',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Đăng ký tài khoản mới' : 'Đăng nhập để tiếp tục',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      hintText: 'ví dụ: nguyen_van_a',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'Tên đăng nhập tối thiểu 3 ký tự';
                      }
                      return null;
                    },
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
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Mật khẩu tối thiểu 8 ký tự';
                      }
                      return null;
                    },
                  ),
                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Đăng ký' : 'Đăng nhập'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                        _successMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký ngay',
                    ),
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
