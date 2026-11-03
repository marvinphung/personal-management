import '../catalog/person_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
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
    return Column(
      children: [
        if (undo?.slot != null)
          ListTile(
            dense: true,
            title: Text(undo!.error ?? 'Đã bỏ qua giao dịch'),
            trailing: undo.slot!.isExpired
                ? null
                : TextButton(
                    onPressed: () => undo.undo(undo.slot!.draftId),
                    child: const Text('Hoàn tác'),
                  ),
          ),
        ListTile(
          title: const Text('Biến động ngân hàng'),
          subtitle: const Text(
            'Giao dịch nhận từ ứng dụng ngân hàng. Phân loại để lưu vào sổ tài chính.',
          ),
          trailing: Text(count?.toString() ?? '…'),
        ),
        Expanded(
          child: drafts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(bankDraftPageProvider),
                child: const Text('Thử lại'),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Không có giao dịch nào đang chờ.'),
                      ),
                    for (final draft in visible)
                      _DraftCard(
                        draft: draft,
                        busy: busy,
                        onIgnore: () => _ignore(draft),
                        onClassify: () => _classify(draft),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: offset == 0
                              ? null
                              : () => setState(() => offset -= 100),
                          child: const Text('Trang trước'),
                        ),
                        TextButton(
                          onPressed: rows.length < 100
                              ? null
                              : () => setState(() => offset += 100),
                          child: const Text('Trang sau'),
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
    final sign = draft.direction == 'income'
        ? '+'
        : draft.direction == 'expense'
        ? '−'
        : '?';
    final color = draft.direction == 'income'
        ? Colors.green.shade700
        : draft.direction == 'expense'
        ? Colors.red.shade700
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank source chip
            Chip(
              label: Text(draft.bankName),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.account_balance, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '$sign${Money.format(draft.amountMinor, draft.currency)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${draft.bankName} · ${_dateLabel(draft.occurredAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (draft.occurredAtSource == 'notification_post_time')
              Text(
                'Thời gian ước tính từ thông báo; vui lòng kiểm tra lại.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (draft.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                draft.description,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : onIgnore,
                  child: const Text('Bỏ qua'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : onClassify,
                  child: const Text('Phân loại'),
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
      // Build transaction
      final transaction = widget.draft.toTransaction(
        repository,
        accountId: selectedAccountId,
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
                  .where((t) => t.text('name').toLowerCase() == name)
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
              a.text('currency') == widget.draft.currency,
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

    // Active debts of correct direction for Công nợ pickers
    final activeDebts = debts
        .where(
          (d) =>
              d.text('status') == 'active' &&
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
        ? Colors.green.shade700
        : Colors.red.shade700;

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

              // Header: amount (read-only, large)
              Text(
                '$sign${Money.format(widget.draft.amountMinor, widget.draft.currency)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Bank + time (read-only small)
              Text(
                '${widget.draft.bankName} · ${_fmtDate(widget.draft.occurredAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.draft.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.draft.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
              if (category != null && !isCongNo) ...[
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
