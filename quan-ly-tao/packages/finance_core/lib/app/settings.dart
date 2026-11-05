import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/bank_import/bank_providers.dart';
import 'components.dart';
import 'language.dart';
import 'providers.dart';
import 'theme.dart';
import 'widget_bridge.dart';
import 'widgets.dart';

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
          contentPadding: EdgeInsets.zero,
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
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // User profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryAccent.withValues(alpha: 0.15),
                child: Icon(Icons.person_rounded, color: colors.primaryAccent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.username ?? 'Tài khoản',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Trạng thái: ${user?.status == "active" ? "Hoạt động" : "Chờ duyệt"}',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Preferences Group
        SettingsGroup(
          title: 'Tùy chọn',
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LanguagePicker(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DropdownButtonFormField<ThemeMode>(
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
            ),
          ],
        ),

        // Features Group
        SettingsGroup(
          title: 'Tính năng & Dữ liệu',
          children: [
            ListTile(
              leading: Icon(Icons.account_balance_rounded, color: colors.primaryAccent),
              title: const Text('Ngân hàng liên kết'),
              subtitle: const Text('Quản lý tài khoản nhận biến động'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/banks'),
            ),
            ListTile(
              leading: Icon(Icons.widgets_rounded, color: colors.primaryAccent),
              title: const Text('Widget màn hình chính'),
              subtitle: const Text('Tiện ích 2×2 / Small xem biến động'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/widget'),
            ),
            ListTile(
              leading: Icon(Icons.category_rounded, color: colors.primaryAccent),
              title: const Text('Danh mục & Thẻ'),
              subtitle: const Text('Quản lý phân loại thu chi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/categories'),
            ),
            ListTile(
              leading: Icon(Icons.handshake_rounded, color: colors.primaryAccent),
              title: const Text('Sổ công nợ'),
              subtitle: const Text('Vay và cho vay'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/debts'),
            ),
            ListTile(
              leading: Icon(Icons.note_alt_rounded, color: colors.primaryAccent),
              title: const Text('Ghi chú tài chính'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/notes'),
            ),
          ],
        ),

        // Sync Group
        const SettingsGroup(
          title: 'Đồng bộ',
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SyncStatus(),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Logout Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.expense,
            side: BorderSide(color: colors.expense.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final hasUnsynced = ref.read(hasUnsyncedChangesProvider).value ?? false;
            if (hasUnsynced) {
              final action = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Thay đổi chưa đồng bộ'),
                  content: const Text(
                    'Bạn đang có dữ liệu hoặc thay đổi chưa được đồng bộ lên máy chủ. Nếu đăng xuất bây giờ, các thay đổi chưa đồng bộ sẽ bị mất.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: colors.expense),
                      onPressed: () => Navigator.pop(context, 'force_logout'),
                      child: const Text('Vẫn đăng xuất'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, 'sync_and_logout'),
                      child: const Text('Đồng bộ & Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (action == null || action == 'cancel') return;
              if (action == 'sync_and_logout') {
                final w = await ref.read(workspaceProvider.future);
                if (w != null) {
                  try {
                    await w.sync.sync();
                  } catch (_) {}
                }
              }
            } else {
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
                      style: FilledButton.styleFrom(backgroundColor: colors.expense),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (okay != true) return;
            }

            try {
              await ref.read(workspaceProvider.notifier).signOut();
            } catch (e) {
              debugPrint('Logout error: $e');
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w600)),
        ),

        const SizedBox(height: 32),
        Center(
          child: Text(
            'Quản lý Tao v1.0',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class WidgetSettingsScreen extends ConsumerWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final pendingCount = ref.watch(bankCountProvider).value ?? 0;
    final isIos = Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget màn hình chính'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Widget Interactive Preview (2x2)
          Center(
            child: Container(
              width: 170,
              height: 170,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.borderSubtle, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.inbox_rounded, color: colors.primaryAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'BIẾN ĐỘNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.income,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    pendingCount.toString(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    pendingCount > 0 ? 'giao dịch cần phân loại' : 'Đã xử lý hết',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                  ),
                  const Spacer(),
                  Text(
                    pendingCount > 0 ? 'Chạm để duyệt →' : 'Không có biến động mới',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Hình ảnh minh họa tiện ích 2×2 trên màn hình chính',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 24),

          // Instructions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isIos ? Icons.phone_iphone_rounded : Icons.android_rounded,
                      color: colors.primaryAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isIos ? 'Cách thêm Widget trên iPhone' : 'Cách thêm Widget trên Android / Samsung',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isIos) ...[
                  _stepItem(colors, '1', 'Quay về Màn hình chính (Home Screen) của iPhone.'),
                  _stepItem(colors, '2', 'Nhấn và giữ vào khoảng trống trên màn hình cho đến khi các ứng dụng rung lắc.'),
                  _stepItem(colors, '3', 'Nhấn vào nút dấu cộng (+) ở góc trên bên trái.'),
                  _stepItem(colors, '4', 'Tìm kiếm "Quản lý Tao" trong danh sách tiện ích.'),
                  _stepItem(colors, '5', 'Chọn kích thước Nhỏ (Small 2×2) và nhấn "Thêm tiện ích".'),
                ] else ...[
                  _stepItem(colors, '1', 'Quay về Màn hình chính điện thoại Android / Samsung One UI.'),
                  _stepItem(colors, '2', 'Nhấn và giữ vào khoảng trống bất kỳ trên màn hình chính.'),
                  _stepItem(colors, '3', 'Chọn biểu tượng "Tiện ích" (Widgets) ở thanh menu dưới.'),
                  _stepItem(colors, '4', 'Tìm ứng dụng "Quản lý Tao" trong danh sách.'),
                  _stepItem(colors, '5', 'Chọn widget "Biến động ngân hàng" kích thước 2×2 và nhấn "Thêm".'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Test & Refresh Actions
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.go('/pending');
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Thử mở màn hình Biến động (Deep link)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final session = ref.read(sessionStateProvider);
              await UserWidgetBridge.updateWidgetCount(
                pendingCount,
                owner: session.user?.id,
                generation: session.generation,
              );
              if (context.mounted) {
                message(context, 'Đã gửi lệnh cập nhật widget!');
              }
            },
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Cập nhật widget ngay bây giờ'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _stepItem(AppThemeColors colors, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.primaryAccent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.4, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
