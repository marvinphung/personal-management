import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/language.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import 'bank_draft_repository.dart';
import 'bank_providers.dart';

class BankImportSettings extends ConsumerStatefulWidget {
  const BankImportSettings({super.key});
  @override
  ConsumerState<BankImportSettings> createState() => _BankImportSettingsState();
}

class _BankImportSettingsState extends ConsumerState<BankImportSettings> {
  bool busy = false;
  Future<void> configure(Map<String, dynamic> values) async {
    setState(() => busy = true);
    try {
      await ref.read(bankDraftRepositoryProvider).configure({
        ...values,
        'language': ref.read(languageProvider) ?? 'en',
      });
      ref.invalidate(bankSettingsProvider);
    } catch (_) {
      if (mounted) {
        message(context, context.tr('Could not update bank import settings.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(bankSettingsProvider);
    final accounts =
        ref
            .watch(recordsProvider(Entity.accounts))
            .value
            ?.where((a) => !a.flag('is_archived'))
            .toList() ??
        [];
    return settings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(bankSettingsProvider),
          child: Text(context.tr('Retry')),
        ),
      ),
      data: (data) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('Bank Notification Import'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Only configured bank apps are processed. Parsing is local, without AI. Failed transactions are ignored. Every draft requires your confirmation.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Automatic transaction detection')),
            value: data['capture'] == true,
            onChanged: busy ? null : (value) => configure({'capture': value}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Notification access')),
            subtitle: Text(
              context.tr(data['access'] == true ? 'Enabled' : 'Disabled'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Notification service')),
            subtitle: Text(
              context.tr(
                data['capture'] != true
                    ? 'Automatic import is off'
                    : data['connected'] == true
                    ? 'Connected'
                    : 'Disconnected',
              ),
            ),
          ),
          if (data['capture'] == true &&
              data['access'] == true &&
              data['connected'] != true)
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('Reconnect notification service')),
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await ref.read(bankDraftRepositoryProvider).reconnect();
                        ref.invalidate(bankSettingsProvider);
                      } catch (_) {
                        if (context.mounted) {
                          message(
                            context,
                            context.tr(
                              'Could not reconnect. Toggle Notification Access off and on.',
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          Text(
            context.tr(
              'Developer mode is not required. If disconnected, reconnect or toggle Notification Access off and on.',
            ),
          ),
          if ((data['lastBankAt'] as num? ?? 0) > 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Last bank notification')),
              subtitle: Text(
                '${context.dateLabel(DateTime.fromMillisecondsSinceEpoch((data['lastBankAt'] as num).toInt()), time: true)} · ${context.tr(switch (data['lastOutcome']) {
                  'created' => 'Draft created',
                  'duplicate' => 'Duplicate ignored',
                  'failed' => 'Failed bank transaction ignored',
                  'unsupported' => 'No supported transaction detected',
                  _ => 'Notification processing error',
                })}',
              ),
            ),
          if (data['access'] != true)
            Text(
              context.tr(
                'Enable notification access so the app can detect bank transactions automatically.',
              ),
            ),
          OutlinedButton(
            onPressed: () async {
              try {
                await ref.read(bankDraftRepositoryProvider).openSettings();
              } catch (_) {
                if (context.mounted) {
                  message(
                    context,
                    context.tr('Could not open notification access settings.'),
                  );
                }
              }
            },
            child: Text(context.tr('Open notification access settings')),
          ),
          const Divider(),
          for (final source in (data['sources'] as List).cast<Map>()) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(source['name'] as String),
              subtitle: Text(source['package'] as String),
              value: source['enabled'] == true,
              onChanged: busy
                  ? null
                  : (v) => configure({'bank': source['code'], 'enabled': v}),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${source['code']}-${source['account']}-${accounts.length}',
              ),
              initialValue: accounts.any((a) => a.id == source['account'])
                  ? source['account'] as String?
                  : '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('Default finance account'),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(context.tr('Choose during review')),
                ),
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.text('name')} (${a.text('currency')})'),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => configure({
                      'bank': source['code'],
                      'account': v == '' ? null : v,
                    }),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: () => context.go('/transactions/pending'),
            icon: const Icon(Icons.inbox_outlined),
            label: Text(context.tr('Pending transactions')),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              'Add Finance Inbox from your Android home screen widget picker. Tapping it opens pending transactions.',
            ),
          ),
          Text(
            context.tr(
              'Signing out clears this device’s bank drafts and import settings. Enable import again after signing in.',
            ),
          ),
          if (kDebugMode)
            TextButton(
              onPressed: () => context.go('/settings/bank-import/parser'),
              child: Text(context.tr('Test parser')),
            ),
        ],
      ),
    );
  }
}

class BankParserScreen extends ConsumerStatefulWidget {
  const BankParserScreen({super.key});
  @override
  ConsumerState<BankParserScreen> createState() => _BankParserScreenState();
}

class _BankParserScreenState extends ConsumerState<BankParserScreen> {
  final text = TextEditingController();
  String bank = 'mbbank';
  Map<String, dynamic>? result;
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !kDebugMode
      ? const SizedBox.shrink()
      : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.tr('Test parser'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            DropdownButton<String>(
              value: bank,
              items: [
                for (final code in [
                  'mbbank',
                  'vietinbank',
                  'bidv',
                  'techcombank',
                  'generic',
                ])
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
              onChanged: (v) => setState(() => bank = v!),
            ),
            TextField(
              controller: text,
              minLines: 5,
              maxLines: 12,
              maxLength: 16384,
              decoration: InputDecoration(
                labelText: context.tr('Paste bank notification here'),
              ),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final parsed = await ref
                            .read(bankDraftRepositoryProvider)
                            .parse(bank, text.text);
                        if (mounted) setState(() => result = parsed);
                      } catch (_) {
                        if (context.mounted) {
                          message(
                            context,
                            context.tr('Could not parse this notification.'),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(context.tr('Parse')),
            ),
            Text(
              context.tr(
                'Preview only. This does not create a draft or a transaction.',
              ),
            ),
            if (result != null)
              SelectableText(
                result!.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              ),
          ],
        );
}
