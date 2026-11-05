import 'dart:async';
import '../features/bank_import/bank_draft_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_language.dart';
import 'providers.dart';

const supportedLanguages = {'en': 'English', 'vi': 'Tiếng Việt'};

/// Non-sensitive, per-account device preference; retained across sign-out.
/// New accounts on a shared device must explicitly make their own choice.
class LanguageController extends Notifier<String?> {
  @override
  String? build() {
    final user = ref.watch(sessionProvider.select((s) => s?.user.id));
    if (user == null) return null;
    final value = ref.read(preferencesProvider).getString('language.$user');
    return supportedLanguages.containsKey(value) ? value : null;
  }

  Future<void> set(String value) async {
    if (!supportedLanguages.containsKey(value)) {
      throw ArgumentError.value(value, 'language');
    }
    final user = ref.read(sessionProvider)?.user.id;
    if (user == null) throw StateError('Language selection requires a session');
    final saved = await ref
        .read(preferencesProvider)
        .setString('language.$user', value);
    if (!saved) throw StateError('Language preference was not saved');
    // A session change during the write must not apply one user's choice to another.
    if (ref.read(sessionProvider)?.user.id == user) {
      state = value;
      if (BankDraftRepository.supported) {
        // The widget preference is secondary; a bridge failure must not undo
        // the app's successfully persisted language choice.
        unawaited(
          ref
              .read(bankDraftRepositoryProvider)
              .configure({'language': value})
              .catchError((Object _) {}),
        );
      }
    }
  }
}

final languageProvider = NotifierProvider<LanguageController, String?>(
  LanguageController.new,
);
final localeProvider = Provider<Locale>(
  (ref) => Locale(ref.watch(languageProvider) ?? 'en'),
);

class LanguagePicker extends ConsumerStatefulWidget {
  const LanguagePicker({super.key});
  @override
  ConsumerState<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends ConsumerState<LanguagePicker> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('${ref.watch(languageProvider)}-$busy'),
        initialValue: ref.watch(languageProvider) ?? 'en',
        decoration: InputDecoration(labelText: context.tr('Language')),
        items: [
          for (final entry in supportedLanguages.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: busy
            ? null
            : (value) async {
                if (value == null) return;
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await ref.read(languageProvider.notifier).set(value);
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error =
                          'Could not save your language. Please try again.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
      ),
      if (error != null)
        Text(
          context.tr(error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

class LanguageWelcomeScreen extends ConsumerStatefulWidget {
  const LanguageWelcomeScreen({super.key});
  @override
  ConsumerState<LanguageWelcomeScreen> createState() =>
      _LanguageWelcomeScreenState();
}

class _LanguageWelcomeScreenState extends ConsumerState<LanguageWelcomeScreen> {
  String selected = 'vi';
  bool busy = false;
  bool failed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          size: 32,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chọn ngôn ngữ\nChoose your language',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bạn có thể đổi lại trong Cài đặt.\nYou can change this later in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final entry in supportedLanguages.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: selected == entry.key
                              ? colors.primary.withValues(alpha: 0.08)
                              : colors.surfaceContainerHighest.withValues(
                                  alpha: 0.4,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: busy
                                ? null
                                : () => setState(() => selected = entry.key),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected == entry.key
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: selected == entry.key
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected == entry.key
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Không thể lưu. Vui lòng thử lại.\nCould not save. Please try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error, fontSize: 13),
                        ),
                      ),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() {
                                busy = true;
                                failed = false;
                              });
                              try {
                                await ref
                                    .read(languageProvider.notifier)
                                    .set(selected);
                              } catch (_) {
                                if (mounted) setState(() => failed = true);
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: Text(
                        busy
                            ? '…'
                            : selected == 'vi'
                            ? 'Tiếp tục'
                            : 'Continue',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
