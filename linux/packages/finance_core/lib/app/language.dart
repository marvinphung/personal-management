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
    if (ref.read(sessionProvider)?.user.id == user) state = value;
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
  String selected = 'en';
  bool busy = false;
  bool failed = false;

  @override
  Widget build(BuildContext context) => PopScope(
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
                  const Icon(Icons.language, size: 48),
                  const SizedBox(height: 24),
                  Text(
                    'Choose your language\nChọn ngôn ngữ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You can change this later in Settings.\nBạn có thể đổi lại trong Cài đặt.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  for (final entry in supportedLanguages.entries)
                    ListTile(
                      title: Text(entry.value),
                      selected: selected == entry.key,
                      leading: Icon(
                        selected == entry.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: busy
                          ? null
                          : () => setState(() => selected = entry.key),
                    ),
                  const SizedBox(height: 24),
                  if (failed)
                    const Text(
                      'Could not save. Please try again.\nKhông thể lưu. Vui lòng thử lại.',
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
