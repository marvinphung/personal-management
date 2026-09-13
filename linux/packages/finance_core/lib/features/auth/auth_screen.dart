import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

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
              'Check your email to confirm your account, then sign in.',
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
            'Unable to sign in or create an account. Check your email, password, confirmation email and connection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                const Icon(Icons.account_balance_wallet_outlined, size: 48),
                const SizedBox(height: 24),
                Text(
                  context.tr('Personal Finance'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('A clear view of your money.'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: context.tr('Email')),
                  validator: (v) => v != null && v.contains('@')
                      ? null
                      : context.tr('Enter a valid email'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  autofillHints: [
                    signup ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: context.tr('Password'),
                  ),
                  validator: (v) => (v?.length ?? 0) >= 8
                      ? null
                      : context.tr('Use at least 8 characters'),
                  onFieldSubmitted: (_) => busy ? null : submit(),
                ),
                const SizedBox(height: 24),
                if (feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(feedback!, semanticsLabel: feedback),
                  ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? context.tr('Please wait…')
                        : signup
                        ? context.tr('Create account')
                        : context.tr('Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          signup = !signup;
                          feedback = null;
                        }),
                  child: Text(
                    signup
                        ? context.tr('Already have an account? Sign in')
                        : context.tr('Create an account'),
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
