import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, busy = false;
  String? feedback;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (signup) {
        final needsConfirmation = await auth.signUp(
          email.text.trim(),
          password.text,
        );
        if (needsConfirmation && mounted) {
          setState(
            () => feedback = context.tr(
              'Kiểm tra email để xác nhận tài khoản, sau đó đăng nhập lại.',
            ),
          );
        }
      } else {
        await auth.signIn(email.text.trim(), password.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => feedback = context.tr(
            'Không thể đăng nhập hoặc tạo tài khoản. Vui lòng kiểm tra lại email, mật khẩu hoặc kết nối mạng.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.savings_outlined,
                        size: 38,
                        color: colors.primaryAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Quản lý PMV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quản lý thu chi, công nợ, đầu tư và lịch cá nhân',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'Vui lòng nhập địa chỉ email hợp lệ',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    autofillHints: [
                      signup
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => (v?.length ?? 0) >= 8
                        ? null
                        : 'Mật khẩu cần tối thiểu 8 ký tự',
                    onFieldSubmitted: (_) => busy ? null : submit(),
                  ),
                  const SizedBox(height: 20),
                  if (feedback != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: colors.expense,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feedback!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.expense,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Vui lòng chờ…'
                          : signup
                          ? 'Tạo tài khoản'
                          : 'Đăng nhập',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            signup = !signup;
                            feedback = null;
                          }),
                    child: Text(
                      signup
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
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
