import 'package:go_router/go_router.dart';
import '../features/bank_import/bank_draft_repository.dart';
import '../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/money.dart';
import 'providers.dart';
import 'language.dart';
import 'widgets.dart';

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider).value,
        pending = ref.watch(pendingProvider).value ?? [];
    if (w == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: w.sync,
      builder: (context, _) => ListTile(
        dense: true,
        leading: Icon(
          w.sync.error != null
              ? Icons.cloud_off
              : w.sync.busy
              ? Icons.sync
              : pending.isEmpty
              ? Icons.cloud_done_outlined
              : Icons.cloud_upload_outlined,
        ),
        title: Text(
          w.sync.error != null
              ? context.tr('Sync failed')
              : w.sync.busy
              ? context.tr('Syncing…')
              : pending.isEmpty
              ? context.tr('Synced')
              : context.tr('{count} changes waiting to sync', {
                  'count': pending.length,
                }),
        ),
        subtitle: w.sync.error != null
            ? Text(context.tr(w.sync.error!))
            : w.sync.notice != null
            ? Text(context.tr(w.sync.notice!))
            : null,
        trailing: IconButton(
          tooltip: context.tr('Sync now'),
          onPressed: w.sync.busy ? null : w.sync.sync,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(ref.watch(sessionProvider)?.user.email ?? ''),
        subtitle: Text(context.tr('Supabase account')),
      ),
      const Divider(),
      const LanguagePicker(),
      const SizedBox(height: 20),
      DropdownButtonFormField<ThemeMode>(
        initialValue: ref.watch(themeProvider),
        decoration: InputDecoration(labelText: context.tr('Theme')),
        items: ThemeMode.values
            .map(
              (t) =>
                  DropdownMenuItem(value: t, child: Text(context.tr(t.name))),
            )
            .toList(),
        onChanged: (t) => ref.read(themeProvider.notifier).set(t!),
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        initialValue: ref.watch(currencyProvider),
        decoration: InputDecoration(
          labelText: context.tr('Dashboard currency'),
        ),
        items: Money.exponents.keys
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (c) => ref.read(currencyProvider.notifier).set(c!),
      ),
      const SizedBox(height: 12),
      Text(
        context.tr(
          'Each account keeps its own currency. Dashboard totals show the selected currency without conversion.',
        ),
      ),
      const Divider(),
      const SyncStatus(),
      if (BankDraftRepository.supported)
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(context.tr('Bank Notification Import')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/bank-import'),
        ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () async {
          final pending = ref.read(pendingProvider).value ?? [];
          if (pending.isNotEmpty) {
            final okay = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.tr('Discard unsynced changes?')),
                content: Text(
                  context.tr(
                    '{count} local operations have not reached Supabase. Sign out clears this device’s private data, including those changes.',
                    {'count': pending.length},
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.tr('Keep working')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.tr('Discard and sign out')),
                  ),
                ],
              ),
            );
            if (okay != true) return;
          }
          try {
            await ref.read(workspaceProvider.notifier).signOut();
          } catch (_) {
            if (context.mounted) {
              message(
                context,
                context.tr('Unable to finish signing out. Please try again.'),
              );
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: Text(context.tr('Sign out')),
      ),
      const SizedBox(height: 32),
      Text(
        context.tr('Personal Finance 1.0'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        context.tr(
          'Offline-first finance for Android and Linux. Your devices connect directly to Supabase. No application server.',
        ),
      ),
      const SizedBox(height: 12),
      Text(
        context.tr(
          'Keyboard: Ctrl+N new transaction · Ctrl+K global search · Ctrl+F search · Escape close dialog',
        ),
      ),
    ],
  );
}
