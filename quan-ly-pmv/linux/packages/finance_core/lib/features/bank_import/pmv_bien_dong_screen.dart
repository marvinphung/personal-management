import '../share_bill/share_bill_controls.dart';
import '../catalog/person_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tag_display.dart';
import '../../core/database/record.dart';
import '../transactions/tag_suggestions.dart';
import '../../core/utils/tag_name.dart';
import 'bank_draft.dart';
import 'bank_draft_repository.dart';
import 'bank_providers.dart';
import 'bank_confirmation.dart';

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

/// Replaces PendingBankScreen as a first-class tab in the PMV app.
class PmvBienDongScreen extends ConsumerStatefulWidget {
  const PmvBienDongScreen({super.key});
  @override
  ConsumerState<PmvBienDongScreen> createState() => _PmvBienDongScreenState();
}

class _PmvBienDongScreenState extends ConsumerState<PmvBienDongScreen> {
  int offset = 0;
  bool busy = false;

  Future<void> _ignore(BankDraft draft) async {
    try {
      final controller = ref.read(undoControllerProvider);
      if (controller == null) return;
      await controller.discard(draft.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã bỏ qua · Hoàn tác trong 3 giây'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              unawaited(controller.undo(draft.id));
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) message(context, userError(context, e));
    }
  }

  // ── Classify ──────────────────────────────────────────────────────────────

  Future<void> _classify(BankDraft draft) async {
    setState(() => busy = true);
    try {
      final workspace = await ref.read(workspaceProvider.future);
      if (workspace == null || workspace.repository.userId != draft.owner) {
        return;
      }
      final settings = await ref.read(bankDraftRepositoryProvider).settings();
      final sources = (settings['sources'] as List).cast<Map>();
      final accountId =
          sources
                  .where((s) => s['code'] == draft.bankCode)
                  .firstOrNull?['account']
              as String?;
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PmvClassifyForm(draft: draft, accountId: accountId),
      );
    } catch (_) {
      if (mounted) {
        message(context, 'Không thể mở màn hình phân loại. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    // After classify completes, refresh
    ref.invalidate(bankDraftPageProvider);
    ref.invalidate(bankCountProvider);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(bankDraftPageProvider(offset));
    final count = ref.watch(bankCountProvider).value;
    final undo = ref.watch(undoControllerProvider);
    final colors = context.colors;

    return Column(
      children: [
        // ── Undo banner ──────────────────────────────────────────────────
        if (undo?.slot != null)
          Material(
            color: colors.bgElevated,
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.undo_rounded,
                size: 18,
                color: colors.primaryAccent,
              ),
              title: Text(
                undo!.error ?? 'Đã bỏ qua giao dịch',
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
              ),
              trailing: undo.slot!.isExpired
                  ? null
                  : TextButton(
                      onPressed: () => undo.undo(undo.slot!.draftId),
                      child: const Text('Hoàn tác'),
                    ),
            ),
          ),

        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biến động ngân hàng',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phân loại để lưu vào sổ tài chính',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count chờ xử lý',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.expense,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: drafts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colors.textMuted),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(bankDraftPageProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
            data: (rows) {
              final visible = rows
                  .where(
                    (d) =>
                        d.id != ref.read(undoControllerProvider)?.slot?.draftId,
                  )
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(bankDraftPageProvider);
                  ref.invalidate(bankCountProvider);
                  await ref.read(bankDraftPageProvider(offset).future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: colors.bgElevated,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 32,
                                color: colors.income,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Không có giao dịch nào đang chờ',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final draft in visible)
                      _DraftCard(
                        draft: draft,
                        busy: busy,
                        onIgnore: () => _ignore(draft),
                        onClassify: () => _classify(draft),
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: offset == 0
                              ? null
                              : () => setState(() => offset -= 100),
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('Trang trước'),
                        ),
                        TextButton.icon(
                          onPressed: rows.length < 100
                              ? null
                              : () => setState(() => offset += 100),
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text('Trang sau'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Draft card widget
// ---------------------------------------------------------------------------

class _DraftCard extends StatelessWidget {
  final BankDraft draft;
  final bool busy;
  final VoidCallback onIgnore;
  final VoidCallback onClassify;
  const _DraftCard({
    required this.draft,
    required this.busy,
    required this.onIgnore,
    required this.onClassify,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isIncome = draft.direction == 'income';
    final isExpense = draft.direction == 'expense';
    final amountColor = isIncome
        ? colors.income
        : isExpense
        ? colors.expense
        : colors.textSecondary;
    final sign = isIncome
        ? '+'
        : isExpense
        ? '−'
        : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank source + direction indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 12,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        draft.bankName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Direction pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isIncome
                        ? 'Tiền vào'
                        : isExpense
                        ? 'Tiền ra'
                        : 'Không rõ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Amount — lớn và nổi bật
            Text(
              '$sign${Money.format(draft.amountMinor, draft.currency)}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: amountColor,
              ),
            ),
            const SizedBox(height: 4),

            // Time
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 12,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  _dateLabel(draft.occurredAt),
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                if (draft.occurredAtSource == 'notification_post_time') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Thời gian ước tính',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Description
            if (draft.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                draft.description,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onIgnore,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Bỏ qua'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: busy ? null : onClassify,
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: const Text('Phân loại'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// PmvClassifyForm — bottom-sheet classify form for bank drafts
// ---------------------------------------------------------------------------

class PmvClassifyForm extends ConsumerStatefulWidget {
  final BankDraft draft;
  final String? accountId;
  const PmvClassifyForm({super.key, required this.draft, this.accountId});
  @override
  ConsumerState<PmvClassifyForm> createState() => _PmvClassifyFormState();
}

class _PmvClassifyFormState extends ConsumerState<PmvClassifyForm> {
  String? category;
  late String? selectedAccountId = widget.accountId;
  final Set<String> selectedTags = {};
  final note = TextEditingController();
  final newTagController = TextEditingController();
  String? actionTag; // for Công nợ categories
  String? personId;
  String? debtId;
  bool busy = false;
  bool shareBillEnabled = false;
  String? shareBillId;
  int shareBillPeople = 1;
  int shareBillPaidPeople = 1;
  String? error;

  @override
  void dispose() {
    note.dispose();
    newTagController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isCongNo(List<Record> categories) {
    if (category == null) return false;
    final cat = categories.where((c) => c.id == category).firstOrNull;
    if (cat == null) return false;
    final beh = cat.text('behavior');
    return beh == 'cong_no_expense' || beh == 'cong_no_income';
  }

  List<String> _actionTagsForCongNo() {
    // For expense Công nợ: Cho vay, Trả nợ
    // For income Công nợ: Thu nợ, Vay nợ
    return widget.draft.direction == 'expense'
        ? ['Cho vay', 'Trả nợ']
        : ['Thu nợ', 'Vay nợ'];
  }

  bool get _needsPersonPicker =>
      _actionTagNeedsNewPerson() &&
      (actionTag == 'Cho vay' || actionTag == 'Vay nợ');

  bool get _needsDebtPicker => actionTag == 'Thu nợ' || actionTag == 'Trả nợ';

  bool _actionTagNeedsNewPerson() =>
      actionTag == 'Cho vay' || actionTag == 'Vay nợ';

  bool get _confirmEnabled {
    if (busy) return false;
    if (category == null) return false;
    // Công nợ requires action tag
    // (we'd need to check categories list, but we track this via actionTag)
    return true;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save(List<Record> allCategories, List<Record> allTags) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final workspace = await ref.read(workspaceProvider.future);
      if (workspace == null) {
        throw const FormatException('Please sign in again');
      }
      final repository = workspace.repository;

      if (_isCongNo(allCategories) &&
          !_actionTagsForCongNo().contains(actionTag)) {
        throw const FormatException('Vui lòng chọn một hành động công nợ.');
      }
      final isIncome = widget.draft.direction == 'income';
      if (shareBillEnabled && isIncome && shareBillId == null) {
        throw const FormatException('Vui lòng chọn Share Bill chưa hoàn tất.');
      }
      final selected = allCategories.where((c) => c.id == category).firstOrNull;
      if (shareBillEnabled &&
          isIncome &&
          !(selected?.text('name').toLowerCase().contains('nhận share') ==
                  true ||
              selected?.text('behavior') == 'share_bill_income')) {
        throw const FormatException('Vui lòng chọn danh mục Nhận share bill.');
      }
      if (shareBillEnabled && !isIncome && _isCongNo(allCategories)) {
        throw const FormatException(
          'Chia bill cần danh mục chi thông thường, không phải Công nợ.',
        );
      }
      // Build transaction
      final transaction = widget.draft.toTransaction(
        repository,
        accountId: selectedAccountId,
        targetCurrency: widget.draft.classificationCurrency,
      );
      final patched = transaction.patch({
        'category_id': category,
        'note': note.text.trim(),
        'exclude_from_totals': false,
      });

      // Resolve tags
      final chosen = <Record>[];
      final tagNames = <String>{...selectedTags};
      // For Công nợ, add the action tag
      if (_isCongNo(allCategories) && actionTag != null) {
        tagNames.add(normalizeTagName(actionTag!));
      }
      // Handle new tag input
      final extra = newTagController.text
          .split(RegExp(r'[,#]+'))
          .map(normalizeTagName)
          .where((s) => s.isNotEmpty)
          .toList();
      tagNames.addAll(extra);

      for (final name in tagNames) {
        chosen.add(
          allTags
                  .where(
                    (t) =>
                        t.text('name').toLowerCase() == name &&
                        t.text('category_id') == category,
                  )
                  .firstOrNull ??
              repository.create(Entity.tags, {
                'name': name,
                'category_id': category,
              }),
        );
      }

      // Borrow/person logic for Công nợ
      Record? borrower;
      Record? linkedDebt;
      if (_isCongNo(allCategories)) {
        if (_actionTagNeedsNewPerson()) {
          final p = (ref.read(recordsProvider(Entity.people)).value ?? [])
              .where((p) => p.id == personId)
              .firstOrNull;
          if (p == null) {
            throw const FormatException(
              'Vui lòng chọn hoặc tạo người liên quan.',
            );
          }
          borrower = p;
        } else if (_needsDebtPicker) {
          final d = (ref.read(recordsProvider(Entity.debts)).value ?? [])
              .where((d) => d.id == debtId)
              .firstOrNull;
          if (d == null) {
            throw const FormatException(
              'Vui lòng chọn khoản công nợ cần thanh toán.',
            );
          }
          linkedDebt = d;
        }
      }

      await saveAndSync(ref, (repo) async {
        await BankConfirmation.save(
          repo,
          widget.draft,
          patched,
          chosen,
          borrower: borrower,
          linkedDebt: linkedDebt,
          shareBillId: shareBillEnabled && isIncome ? shareBillId : null,
          createShareBill: shareBillEnabled && !isIncome,
          shareBillPaidPeople: shareBillPaidPeople,
          shareBillPeople: shareBillPeople,
          disbursementDirection: actionTag == 'Cho vay'
              ? DebtDirection.lent
              : actionTag == 'Vay nợ'
              ? DebtDirection.borrowed
              : null,
        );
      });

      await ref
          .read(bankDraftRepositoryProvider)
          .finish(widget.draft, confirmed: true);
      ref.invalidate(bankDraftPageProvider);
      ref.invalidate(bankCountProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allCategories =
        ref.watch(recordsProvider(Entity.categories)).value ?? [];
    final allTags = ref.watch(recordsProvider(Entity.tags)).value ?? [];
    final links =
        ref.watch(recordsProvider(Entity.transactionTags)).value ?? [];
    final people = ref.watch(recordsProvider(Entity.people)).value ?? [];
    final debts = ref.watch(recordsProvider(Entity.debts)).value ?? [];

    final accounts = (ref.watch(recordsProvider(Entity.accounts)).value ?? [])
        .where(
          (a) =>
              !a.flag('is_archived') &&
              a.text('currency') == widget.draft.classificationCurrency,
        )
        .toList();
    final needsAccount = !accounts.any((a) => a.id == widget.accountId);
    final direction = widget.draft.direction; // 'income' or 'expense'
    final topCategoryIds =
        ref.watch(categoryRankProvider(direction)).value ?? [];

    // Filtered categories for this direction
    final directionCategories = allCategories
        .where(
          (c) =>
              !c.flag('is_archived') &&
              (c.text('type') == direction || c.text('type') == 'both'),
        )
        .toList();

    // Top-5 by rank, then "Khác" to open full list
    final topCategories = topCategoryIds
        .map((id) => directionCategories.where((c) => c.id == id).firstOrNull)
        .whereType<Record>()
        .take(5)
        .toList();

    for (final candidate in directionCategories) {
      if (topCategories.length == 5) break;
      if (!topCategories.any((c) => c.id == candidate.id)) {
        topCategories.add(candidate);
      }
    }

    // Tags for selected category
    final categoryTags = category == null
        ? <Record>[]
        : tagSuggestions(
            allTags,
            links,
          ).where((t) => t.text('category_id') == category).toList();

    final isCongNo = _isCongNo(allCategories);
    final shareBills =
        (ref.watch(recordsProvider(Entity.shareBills)).value ?? [])
            .where(
              (b) =>
                  !b.deleted &&
                  b.text('status') == 'active' &&
                  b.text('currency') == widget.draft.classificationCurrency,
            )
            .toList();
    final shareCategory = directionCategories
        .where(
          (c) =>
              c.text('name').toLowerCase().contains('nhận share') ||
              c.text('behavior') == 'share_bill_income',
        )
        .firstOrNull;

    // Active debts of correct direction for Công nợ pickers
    final activeDebts = debts
        .where(
          (d) =>
              d.text('status') == 'active' &&
              d.text('currency') == widget.draft.classificationCurrency &&
              d.text('direction') ==
                  (actionTag == 'Thu nợ'
                      ? 'lent'
                      : actionTag == 'Trả nợ'
                      ? 'borrowed'
                      : ''),
        )
        .toList();

    final sign = direction == 'income' ? '+' : '−';
    final amountColor = direction == 'income'
        ? context.colors.income
        : context.colors.expense;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: amount + bank info trong container nổi bật
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: amountColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sign${Money.format(widget.draft.amountMinor, widget.draft.currency)}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 12,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.draft.bankName} · ${_fmtDate(widget.draft.occurredAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (widget.draft.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.draft.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              if (widget.draft.currency == 'USD') ...[
                const SizedBox(height: 12),
                Text(
                  '1 USD = 27,000 VND · Ghi sổ: '
                  '${Money.format(widget.draft.classificationAmount, 'VND')}',
                ),
              ],
              const SizedBox(height: 20),
              if (needsAccount)
                RecordPicker(
                  label: 'Tài khoản ghi sổ',
                  value: accounts.any((a) => a.id == selectedAccountId)
                      ? selectedAccountId
                      : null,
                  records: accounts,
                  optional: false,
                  onChanged: (id) => setState(() => selectedAccountId = id),
                ),
              if (direction == 'income' ||
                  (direction == 'expense' && !isCongNo))
                ShareBillControls(
                  income: direction == 'income',
                  enabled: shareBillEnabled,
                  people: shareBillPeople,
                  paidPeople: shareBillPaidPeople,
                  onPaidPeople: (v) => setState(() => shareBillPaidPeople = v),
                  bills: shareBills,
                  billId: shareBillId,
                  onEnabled: (v) => setState(() {
                    shareBillEnabled = v;
                    shareBillId = null;
                    shareBillPeople = 1;
                    shareBillPaidPeople = 1;
                    if (v && direction == 'income' && shareCategory != null) {
                      category = shareCategory.id;
                      selectedTags.clear();
                      newTagController.clear();
                      actionTag = null;
                    }
                  }),
                  onPeople: (v) => setState(() => shareBillPeople = v),
                  onBill: (v) => setState(() => shareBillId = v),
                ),

              if (!(shareBillEnabled && direction == 'income')) ...[
                Text('Danh mục', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),

                // Top-5 category quick picks
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final cat in topCategories)
                      ChoiceChip(
                        label: Text(cat.text('name')),
                        selected: category == cat.id,
                        onSelected: (_) => setState(() {
                          category = cat.id;
                          if (_isCongNo(allCategories)) {
                            shareBillEnabled = false;
                          }
                          selectedTags.clear();
                          actionTag = null;
                          personId = null;
                          debtId = null;
                        }),
                      ),
                    // "Khác" button opens full category picker
                    ActionChip(
                      avatar: const Icon(Icons.more_horiz, size: 16),
                      label: const Text('Khác'),
                      onPressed: () async {
                        final picked = await _pickCategory(
                          context,
                          directionCategories,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            category = picked;
                            if (_isCongNo(allCategories)) {
                              shareBillEnabled = false;
                            }
                            selectedTags.clear();
                            actionTag = null;
                            personId = null;
                            debtId = null;
                          });
                        }
                      },
                    ),
                  ],
                ),

                // Show selected category name if picked via "Khác"
                if (category != null &&
                    !topCategories.any((c) => c.id == category)) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Đã chọn: ${directionCategories.where((c) => c.id == category).firstOrNull?.text('name') ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],

              // Công nợ action tag selector
              if (isCongNo) ...[
                const SizedBox(height: 16),
                Text(
                  'Hành động',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _actionTagsForCongNo()
                      .map(
                        (tag) => ChoiceChip(
                          label: Text(tag),
                          selected: actionTag == tag,
                          onSelected: (_) => setState(() {
                            actionTag = tag;
                            personId = null;
                            debtId = null;
                          }),
                        ),
                      )
                      .toList(),
                ),
                // Person picker for Cho vay / Vay nợ
                if (_needsPersonPicker) ...[
                  const SizedBox(height: 12),
                  PersonPicker(
                    label: 'Người liên quan',
                    value: personId,
                    records: people,
                    onChanged: (v) => setState(() => personId = v),
                  ),
                ],
                // Debt picker for Thu nợ / Trả nợ
                if (_needsDebtPicker && activeDebts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  RecordPicker(
                    label: 'Chọn danh sách công nợ',
                    value: debtId,
                    records: activeDebts,
                    onChanged: (v) => setState(() => debtId = v),
                    optional: false,
                  ),
                ],
              ],

              if (isCongNo && direction == 'expense')
                Wrap(
                  spacing: 6,
                  children: categoryTags
                      .where((t) => TagDisplay.forRecord(t) == 'Mua chung')
                      .map(
                        (t) => FilterChip(
                          label: Text('#${TagDisplay.forRecord(t)}'),
                          selected: selectedTags.contains(t.text('name')),
                          onSelected: (v) => setState(() {
                            if (v) {
                              selectedTags.add(t.text('name'));
                            } else {
                              selectedTags.remove(t.text('name'));
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),

              // Tag chips (non-Công nợ multi-select, Công nợ handled above)
              if (category != null &&
                  !isCongNo &&
                  !(shareBillEnabled && direction == 'income')) ...[
                const SizedBox(height: 16),
                Text('Tags', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: categoryTags
                      .map(
                        (t) => FilterChip(
                          label: Text('#${TagDisplay.forRecord(t)}'),
                          selected: selectedTags.contains(
                            t.text('name').toLowerCase(),
                          ),
                          onSelected: (v) => setState(() {
                            if (v) {
                              selectedTags.add(t.text('name').toLowerCase());
                            } else {
                              selectedTags.remove(t.text('name').toLowerCase());
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
                // Inline tag creation
                const SizedBox(height: 8),
                TextField(
                  controller: newTagController,
                  decoration: const InputDecoration(
                    labelText: 'Thêm tag mới (tuỳ chọn)',
                    hintText: '#caphe, #antrua',
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                ),
                maxLines: 1,
              ),

              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _confirmEnabled
                    ? () => _save(allCategories, allTags)
                    : null,
                child: Text(busy ? 'Đang lưu…' : 'Xác nhận'),
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _pickCategory(
    BuildContext context,
    List<Record> categories,
  ) => showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn danh mục'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: categories
              .map(
                (c) => ListTile(
                  title: Text(c.text('name')),
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Backward-compatible alias
// ---------------------------------------------------------------------------

/// Alias so that any existing code using PendingBankScreen still compiles.
typedef PendingBankScreen = PmvBienDongScreen;
