import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_language.dart';
import '../core/utils/money.dart';
import '../features/bank_import/bank_draft_repository.dart';
import 'components.dart';
import 'language.dart';
import 'providers.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SyncStatus
// ─────────────────────────────────────────────────────────────────────────────

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(workspaceProvider).value,
        pending = ref.watch(pendingProvider).value ?? [];
    if (w == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: w.sync,
      builder: (context, _) {
        final colors = context.colors;
        final (icon, label, subtitle) = w.sync.error != null
            ? (
                Icons.cloud_off_outlined,
                context.tr('Đồng bộ thất bại'),
                context.tr(w.sync.error!),
              )
            : w.sync.busy
            ? (Icons.sync_rounded, context.tr('Đang đồng bộ…'), null)
            : pending.isEmpty
            ? (Icons.cloud_done_outlined, context.tr('Đã đồng bộ'), null)
            : (
                Icons.cloud_upload_outlined,
                context.tr('{count} thay đổi chờ đồng bộ', {
                  'count': pending.length,
                }),
                null,
              );

        return ListTile(
          dense: true,
          leading: Icon(
            icon,
            size: 18,
            color: w.sync.error != null ? colors.expense : colors.textMuted,
          ),
          title: Text(
            label,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                )
              : null,
          trailing: IconButton(
            tooltip: context.tr('Đồng bộ ngay'),
            onPressed: w.sync.busy ? null : w.sync.sync,
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: colors.textMuted,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userEmail = ref.watch(sessionProvider)?.user.email ?? '';
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── User card ──────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: colors.primaryAccent.withValues(alpha: 0.12),
              child: Icon(
                Icons.person_outline_rounded,
                color: colors.primaryAccent,
              ),
            ),
            title: Text(
              userEmail.isEmpty ? 'Quản lý PMV' : userEmail,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              context.tr('Tài khoản Supabase'),
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Chức năng ─────────────────────────────────────────────────────
        SettingsGroup(
          title: 'Chức năng',
          children: [
            _SettingsTile(
              icon: Icons.handshake_outlined,
              iconColor: Colors.blue.shade700,
              title: 'Công nợ',
              subtitle: 'Quản lý cho vay và vay nợ',
              onTap: () => context.go('/debts'),
            ),
            _SettingsTile(
              icon: Icons.group_outlined,
              iconColor: Colors.teal.shade600,
              title: 'Share Bill',
              subtitle: 'Theo dõi bill chia nhóm và nhận lại tiền',
              onTap: () => context.go('/share-bills'),
            ),
            _SettingsTile(
              icon: Icons.trending_up_rounded,
              iconColor: Colors.green.shade700,
              title: 'Đầu tư',
              subtitle: 'Theo dõi vốn bỏ vào và tiền nhận về',
              onTap: () => context.go('/investments'),
            ),
            _SettingsTile(
              icon: Icons.calendar_month_outlined,
              iconColor: Colors.orange.shade700,
              title: 'Lịch',
              subtitle: 'Xem lịch công việc từ Google Calendar',
              onTap: () => context.go('/calendar'),
            ),
            _SettingsTile(
              icon: Icons.notes_rounded,
              iconColor: Colors.purple.shade600,
              title: 'Ghi chú',
              subtitle: 'Ghi chú cá nhân và ghim',
              onTap: () => context.go('/notes'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Danh mục & Dữ liệu ────────────────────────────────────────────
        SettingsGroup(
          title: 'Danh mục & Dữ liệu',
          children: [
            _SettingsTile(
              icon: Icons.category_outlined,
              title: 'Danh mục',
              onTap: () => context.go('/categories'),
            ),
            _SettingsTile(
              icon: Icons.label_outline_rounded,
              title: 'Thẻ (Tags)',
              onTap: () => context.go('/tags'),
            ),
            _SettingsTile(
              icon: Icons.people_outline_rounded,
              title: 'Người liên quan',
              onTap: () => context.go('/people'),
            ),
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Tài khoản',
              onTap: () => context.go('/accounts'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Ngân hàng ─────────────────────────────────────────────────────
        if (BankDraftRepository.supported) ...[
          SettingsGroup(
            title: 'Ngân hàng',
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: colors.primaryAccent,
                title: 'Import thông báo ngân hàng',
                subtitle: 'Cấu hình nhận thông báo biến động số dư',
                onTap: () => context.go('/settings/bank-import'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // ── Tùy chỉnh & Đồng bộ ──────────────────────────────────────────
        SettingsGroup(
          title: 'Tùy chỉnh & Đồng bộ',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: ref.watch(themeProvider),
                decoration: InputDecoration(labelText: context.tr('Giao diện')),
                items: ThemeMode.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == ThemeMode.system
                              ? 'Theo hệ thống'
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
                  labelText: context.tr('Tiền tệ hiển thị'),
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

        const SizedBox(height: 8),

        // ── Footer ────────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Icon(
                Icons.savings_outlined,
                color: colors.primaryAccent,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                'Quản lý PMV',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ứng dụng quản lý tài chính và lịch cá nhân',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsTile — ListTile chuẩn với icon avatar
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icoColor = iconColor ?? colors.textSecondary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: icoColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: icoColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            )
          : null,
      trailing: Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
      onTap: onTap,
    );
  }
}
