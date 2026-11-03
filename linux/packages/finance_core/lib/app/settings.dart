import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_language.dart';
import '../core/utils/money.dart';
import '../features/bank_import/bank_draft_repository.dart';
import 'components.dart';
import 'language.dart';
import 'providers.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(sessionProvider)?.user.email ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // User info card
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              userEmail.isEmpty ? 'Quản lý PMV' : userEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(context.tr('Supabase account')),
          ),
        ),
        const SizedBox(height: 12),

        // Group 1: Chức năng PMV
        SettingsGroup(
          title: 'Chức năng',
          children: [
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Công nợ'),
              subtitle: const Text('Quản lý cho vay và vay nợ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/debts'),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Đầu tư'),
              subtitle: const Text('Theo dõi vốn bỏ vào và tiền nhận về'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/investments'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Lịch'),
              subtitle: const Text('Xem lịch công việc từ Google Calendar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/calendar'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Ghi chú'),
              subtitle: const Text('Ghi chú cá nhân và ghim'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/notes'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Group 2: Danh mục & Thẻ
        SettingsGroup(
          title: 'Danh mục & Dữ liệu',
          children: [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Danh mục'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/categories'),
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Thẻ (Tags)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/tags'),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Người liên quan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/people'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/accounts'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Group 3: Ngân hàng
        if (BankDraftRepository.supported) ...[
          SettingsGroup(
            title: 'Ngân hàng',
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('Bank Notification Import')),
                subtitle: const Text('Cấu hình nhận thông báo biến động số dư'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/bank-import'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Group 4: Giao diện & Hệ thống
        SettingsGroup(
          title: 'Tùy chỉnh & Đồng bộ',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: ref.watch(themeProvider),
                decoration: InputDecoration(labelText: context.tr('Theme')),
                items: ThemeMode.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == ThemeMode.system
                              ? 'Hệ thống'
                              : (t == ThemeMode.light ? 'Sáng' : 'Tối'),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (t) => ref.read(themeProvider.notifier).set(t!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                initialValue: ref.watch(currencyProvider),
                decoration: InputDecoration(
                  labelText: context.tr('Dashboard currency'),
                ),
                items: Money.exponents.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (c) => ref.read(currencyProvider.notifier).set(c!),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LanguagePicker(),
            ),
            const SyncStatus(),
          ],
        ),
        const SizedBox(height: 20),

        // Sign out button
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
        const SizedBox(height: 24),

        // App Footer
        const Center(
          child: Column(
            children: [
              Text(
                'Quản lý PMV',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Ứng dụng quản lý tài chính và lịch cá nhân',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
