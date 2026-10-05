import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'language.dart';
import 'providers.dart';

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider).value,
        pending = ref.watch(pendingProvider).value ?? [];
    if (w == null || w.sync.stopped) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: w.sync,
      builder: (context, _) {
        if (w.sync.stopped) return const SizedBox.shrink();
        return ListTile(
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
              ? 'Lỗi đồng bộ'
              : w.sync.busy
                  ? 'Đang đồng bộ…'
                  : pending.isEmpty
                      ? 'Đã đồng bộ'
                      : '${pending.length} thay đổi đang chờ đồng bộ',
        ),
        subtitle: w.sync.error != null
            ? Text(w.sync.error!)
            : w.sync.notice != null
                ? Text(w.sync.notice!)
                : null,
        trailing: IconButton(
          tooltip: 'Đồng bộ ngay',
          onPressed: w.sync.busy ? null : w.sync.sync,
          icon: const Icon(Icons.refresh),
        ),
      );
      },
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final currentTheme = ref.watch(themeProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user?.username ?? 'Tài khoản'),
          subtitle: Text('Trạng thái: ${user?.status == "active" ? "Hoạt động" : "Chờ duyệt"}'),
        ),
        const Divider(),
        const LanguagePicker(),
        const SizedBox(height: 12),
        Text('Giao diện', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<ThemeMode>(
          isExpanded: true,
          initialValue: currentTheme,
          decoration: const InputDecoration(labelText: 'Chế độ hiển thị'),
          items: const [
            DropdownMenuItem(value: ThemeMode.system, child: Text('Theo hệ thống')),
            DropdownMenuItem(value: ThemeMode.light, child: Text('Giao diện Sáng (Light)')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('Giao diện Tối (Dark)')),
          ],
          onChanged: (t) {
            if (t != null) ref.read(themeProvider.notifier).set(t);
          },
        ),
        const SizedBox(height: 20),
        Text('Tính năng', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance),
          title: const Text('Ngân hàng liên kết'),
          subtitle: const Text('Quản lý tài khoản nhận biến động'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/banks'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.category_outlined),
          title: const Text('Danh mục & Thẻ'),
          subtitle: const Text('Quản lý phân loại thu chi'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/categories'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.handshake_outlined),
          title: const Text('Sổ công nợ'),
          subtitle: const Text('Vay và cho vay'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/debts'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes_outlined),
          title: const Text('Ghi chú tài chính'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/notes'),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text('Đồng bộ', style: Theme.of(context).textTheme.titleMedium),
        const SyncStatus(),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () async {
            final okay = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Đăng xuất?'),
                content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi Quản lý Tao không?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            );
            if (okay != true) return;

            try {
              await ref.read(workspaceProvider.notifier).signOut();
            } catch (e) {
              debugPrint('Logout error: $e');
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            'Quản lý Tao v1.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
