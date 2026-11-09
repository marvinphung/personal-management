import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/language.dart';
import '../../app/theme.dart';
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
  String? debugResult;
  Future<void> runDebug() async {
    setState(() {
      busy = true;
      debugResult = null;
    });
    try {
      final result = await ref
          .read(bankDraftRepositoryProvider)
          .debug()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final status = result['status'];
      setState(
        () => debugResult = switch (status) {
          'connected' when result['connected'] == true =>
            'Bộ đọc đang kết nối. Hãy thử một thông báo ngân hàng mới.',
          'recovered' when result['connected'] == true =>
            'Đã kết nối lại bộ đọc. Hãy thử một thông báo ngân hàng mới.',
          'permission_required' =>
            'Chưa có quyền đọc thông báo. Bấm Cài đặt để cấp quyền cho PMV.',
          'capture_disabled' =>
            'Thu thập đang tắt. Bật Tự động nhận diện biến động nếu muốn nhận giao dịch.',
          'session_changed' =>
            'Phiên đăng nhập đã thay đổi. Vui lòng mở lại màn hình này.',
          'busy' => 'Debug đang chạy. Vui lòng chờ kết quả.',
          _ =>
            'Chưa khôi phục được bộ đọc. Thử tắt/bật quyền đọc thông báo trong Cài đặt Android. Nếu hệ thống vẫn kẹt, có thể cần khởi động lại máy.',
        },
      );
      ref.invalidate(bankSettingsProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => debugResult = 'Không chạy được Debug. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
    final colors = context.colors;
    final settings = ref.watch(bankSettingsProvider);
    final accounts =
        ref
            .watch(recordsProvider(Entity.accounts))
            .value
            ?.where((a) => !a.flag('is_archived'))
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import thông báo ngân hàng'),
        actions: [
          TextButton.icon(
            onPressed: busy ? null : runDebug,
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Debug'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (debugResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                debugResult!,
                key: const ValueKey('bank-debug-result'),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: settings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(bankSettingsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('Thử lại')),
                    ),
                  ],
                ),
              ),
              data: (data) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // ── Banner giới thiệu ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primaryAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primaryAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 20,
                          color: colors.primaryAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Xử lý hoàn toàn cục bộ trên thiết bị Samsung A54, không gửi thông báo ra ngoài. Mọi giao dịch đều cần bạn xác nhận.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Group 1: Trạng thái & Quyền truy cập ────────────────────────
                  SettingsGroup(
                    title: 'Trạng thái hoạt động',
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        title: const Text(
                          'Tự động nhận diện biến động',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Bắt thông báo từ các ứng dụng ngân hàng được chọn',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: data['capture'] == true,
                        onChanged: busy
                            ? null
                            : (value) => configure({'capture': value}),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: Icon(
                          data['access'] == true
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          color: data['access'] == true
                              ? colors.income
                              : colors.warning,
                          size: 22,
                        ),
                        title: const Text('Quyền đọc thông báo'),
                        subtitle: Text(
                          data['access'] == true
                              ? 'Đã cấp quyền'
                              : 'Chưa cấp quyền',
                          style: TextStyle(
                            color: data['access'] == true
                                ? colors.income
                                : colors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(bankDraftRepositoryProvider)
                                  .openSettings();
                            } catch (_) {
                              if (context.mounted) {
                                message(
                                  context,
                                  context.tr(
                                    'Không thể mở cài đặt quyền thông báo.',
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Cài đặt'),
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        leading: Icon(
                          data['capture'] != true
                              ? Icons.pause_circle_outline
                              : data['connected'] == true
                              ? Icons.sync_rounded
                              : Icons.sync_problem_rounded,
                          color: data['connected'] == true
                              ? colors.income
                              : colors.textMuted,
                          size: 22,
                        ),
                        title: const Text('Dịch vụ nền (Listener Service)'),
                        subtitle: Text(
                          data['capture'] != true
                              ? 'Đang tắt nhận diện'
                              : data['connected'] == true
                              ? 'Đang kết nối bình thường'
                              : 'Mất kết nối',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        trailing:
                            (data['capture'] == true &&
                                data['access'] == true &&
                                data['connected'] != true)
                            ? FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        setState(() => busy = true);
                                        try {
                                          await ref
                                              .read(bankDraftRepositoryProvider)
                                              .reconnect();
                                          ref.invalidate(bankSettingsProvider);
                                        } catch (_) {
                                          if (context.mounted) {
                                            message(
                                              context,
                                              context.tr(
                                                'Không thể kết nối lại. Vui lòng bật lại quyền Thông báo.',
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => busy = false);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Kết nối lại'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(100, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if ((data['lastBankAt'] as num? ?? 0) > 0)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          leading: const Icon(Icons.history_rounded, size: 22),
                          title: const Text('Thông báo ngân hàng gần nhất'),
                          subtitle: Text(
                            '${context.dateLabel(DateTime.fromMillisecondsSinceEpoch((data['lastBankAt'] as num).toInt()), time: true)} · ${switch (data['lastOutcome']) {
                              'created' => 'Đã tạo bản nháp',
                              'duplicate' => 'Bỏ qua (trùng lặp)',
                              'failed' => 'Giao dịch thất bại (đã bỏ qua)',
                              'unsupported' => 'Không nhận diện được nội dung',
                              _ => 'Lỗi xử lý',
                            }}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Group 2: Danh sách ứng dụng ngân hàng ────────────────────────
                  SettingsGroup(
                    title: 'Ngân hàng hỗ trợ',
                    children: [
                      for (final source
                          in (data['sources'] as List).cast<Map>())
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: colors.bgElevated,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_rounded,
                                      size: 18,
                                      color: colors.primaryAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          source['name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          source['package'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: source['enabled'] == true,
                                    onChanged: busy
                                        ? null
                                        : (v) => configure({
                                            'bank': source['code'],
                                            'enabled': v,
                                          }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '${source['code']}-${source['account']}-${accounts.length}',
                                ),
                                initialValue:
                                    accounts.any(
                                      (a) => a.id == source['account'],
                                    )
                                    ? source['account'] as String?
                                    : '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Tài khoản ghi sổ mặc định',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('Chọn khi phân loại'),
                                  ),
                                  for (final a in accounts)
                                    DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        '${a.text('name')} (${a.text('currency')})',
                                      ),
                                    ),
                                ],
                                onChanged: busy
                                    ? null
                                    : (v) => configure({
                                        'bank': source['code'],
                                        'account': v == '' ? null : v,
                                      }),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Phím tắt mở Biến động ──────────────────────────────────────
                  FilledButton.icon(
                    onPressed: () => context.go('/transactions/pending'),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Xem danh sách biến động đang chờ'),
                  ),
                  const SizedBox(height: 12),

                  // ── Test parser (Debug mode only) ──────────────────────────────
                  if (kDebugMode)
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            context.go('/settings/bank-import/parser'),
                        icon: const Icon(Icons.bug_report_outlined, size: 16),
                        label: const Text(
                          'Kiểm thử bộ phân tích (Parser Test)',
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
      : Scaffold(
          appBar: AppBar(title: const Text('Kiểm thử parser thông báo')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: bank,
                decoration: const InputDecoration(labelText: 'Ngân hàng'),
                items: [
                  for (final code in [
                    'mbbank',
                    'vietinbank',
                    'bidv',
                    'techcombank',
                    'generic',
                  ])
                    DropdownMenuItem(
                      value: code,
                      child: Text(code.toUpperCase()),
                    ),
                ],
                onChanged: (v) => setState(() => bank = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 8,
                maxLength: 16384,
                decoration: const InputDecoration(
                  labelText: 'Dán nội dung thông báo ngân hàng vào đây',
                ),
              ),
              const SizedBox(height: 12),
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
                              context.tr('Không thể phân tích thông báo này.'),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(busy ? 'Đang phân tích…' : 'Phân tích'),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    result!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
}
