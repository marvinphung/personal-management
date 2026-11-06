import '../catalog/person_picker.dart';
import '../../core/utils/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tag_display.dart';
import '../../core/utils/tag_name.dart';
import '../bank_import/bank_confirmation.dart';
import '../bank_import/bank_draft.dart';
import '../bank_import/bank_draft_repository.dart';
import '../bank_import/bank_providers.dart';
import '../debts/debt_service.dart';
import 'tag_suggestions.dart';

Future<void> showTransactionForm(
  BuildContext context, {
  Record? record,
  String? initialCategory,
  String? initialType,
}) => showDialog<void>(
  context: context,
  builder: (_) => TransactionForm(
    record: record,
    initialCategory: initialCategory,
    initialType: initialType,
  ),
);

class TransactionForm extends ConsumerStatefulWidget {
  final Record? record;
  final BankDraft? bankDraft;
  final String? initialCategory, initialType;
  const TransactionForm({
    super.key,
    this.record,
    this.bankDraft,
    this.initialCategory,
    this.initialType,
  });
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final amount = TextEditingController(),
      description = TextEditingController(),
      note = TextEditingController(),
      tagInput = TextEditingController();
  String type = 'expense';
  String? reviewCurrency;
  String? account, from, to, category, error, borrower;
  String? actionTag;
  String? selectedDebtId;
  DateTime occurred = DateTime.now();
  final selectedTags = <String>{};
  bool busy = false, initialized = false;
  bool get bankReadOnly =>
      widget.bankDraft != null || widget.record?.data['bank_source'] != null;

  @override
  void initState() {
    super.initState();
    category = widget.initialCategory;
    type = widget.initialType ?? type;
    final r = widget.record;
    if (r != null) {
      amount.text = Money.groupedInput(r.money('amount'), r.text('currency'));
      description.text = r.text('description');
      note.text = r.text('note');
      type = r.text('type');
      if (widget.bankDraft != null) reviewCurrency = r.text('currency');
      account = r.data['account_id'];
      from = r.data['from_account_id'];
      to = r.data['to_account_id'];
      category = r.data['category_id'];
      occurred = r.date('occurred_at');
    }
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    note.dispose();
    tagInput.dispose();
    super.dispose();
  }

  Future<void> save(
    List<Record> accounts,
    List<Record> tags, {
    bool isCongNo = false,
    List<Record> people = const [],
    List<Record> debts = const [],
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = accounts
          .where((a) => a.id == (type == 'transfer' ? from : account))
          .firstOrNull;
      if (picked == null) {
        throw const FormatException('Vui lòng tạo hoặc chọn tài khoản trước.');
      }
      if (reviewCurrency != null && reviewCurrency != picked.text('currency')) {
        throw const FormatException('Loại tiền tệ của tài khoản không khớp.');
      }
      final value = Money.parse(amount.text, currency: picked.text('currency'));
      if (type != 'transfer' && category == null) {
        throw const FormatException('Vui lòng chọn danh mục.');
      }
      if (isCongNo && actionTag == null) {
        throw const FormatException('Vui lòng chọn hành động công nợ.');
      }

      await saveAndSync(ref, (repository) async {
        final values = {
          'exclude_from_totals': false,
          'type': type,
          'amount': value,
          'currency': picked.text('currency'),
          'description': description.text.trim(),
          'note': note.text.trim(),
          'occurred_at': occurred.toUtc().toIso8601String(),
          'account_id': type == 'transfer' ? null : account,
          'from_account_id': type == 'transfer' ? from : null,
          'to_account_id': type == 'transfer' ? to : null,
          'category_id': type == 'transfer' ? null : category,
        };
        final transaction =
            widget.record?.patch(values) ??
            repository.create(Entity.transactions, values);
        final chosen = <Record>[];
        final names = {
          ...selectedTags,
          ...tagInput.text
              .split(RegExp(r'[,#]+'))
              .map(normalizeTagName)
              .where((s) => s.isNotEmpty),
        };
        if (isCongNo && actionTag != null) {
          names.add(normalizeTagName(actionTag!));
        }

        for (final name in names) {
          final existingTag = tags
              .where((t) => t.text('name').toLowerCase() == name)
              .firstOrNull;
          if (!selectedTags.contains(name) &&
              existingTag != null &&
              existingTag.text('category_id') != category) {
            throw const FormatException('Thẻ này thuộc danh mục khác.');
          }
          chosen.add(
            existingTag ??
                repository.create(Entity.tags, {
                  'name': name,
                  'category_id': category,
                }),
          );
        }

        final person = people.where((p) => p.id == borrower).firstOrNull;
        final targetDebt = debts
            .where((d) => d.id == selectedDebtId)
            .firstOrNull;

        if (isCongNo) {
          if (actionTag == 'Cho vay' || actionTag == 'Vay nợ') {
            if (person == null) {
              throw const FormatException('Create or select a person first');
            }
          } else if (actionTag == 'Thu nợ' || actionTag == 'Trả nợ') {
            if (targetDebt == null) {
              throw const FormatException(
                'Vui lòng chọn khoản công nợ cần thanh toán.',
              );
            }
          }
        }

        if (widget.bankDraft != null) {
          await BankConfirmation.save(
            repository,
            widget.bankDraft!,
            transaction,
            chosen,
            borrower: person,
            linkedDebt: targetDebt,
            disbursementDirection: actionTag == 'Cho vay'
                ? DebtDirection.lent
                : actionTag == 'Vay nợ'
                ? DebtDirection.borrowed
                : null,
          );
        } else if (isCongNo && actionTag == 'Cho vay') {
          await DebtService(repository).saveDisbursementTransaction(
            transaction,
            person!,
            DebtDirection.lent,
            chosen,
          );
        } else if (isCongNo && actionTag == 'Vay nợ') {
          await DebtService(repository).saveDisbursementTransaction(
            transaction,
            person!,
            DebtDirection.borrowed,
            chosen,
          );
        } else if (isCongNo &&
            (actionTag == 'Thu nợ' || actionTag == 'Trả nợ')) {
          await DebtService(
            repository,
          ).saveRepaymentTransaction(transaction, targetDebt!, chosen);
        } else {
          await repository.saveTransaction(transaction, chosen);
        }
        await repository.rememberSelections(picked.id, category);
      });

      if (widget.bankDraft != null) {
        try {
          await ref
              .read(bankDraftRepositoryProvider)
              .finish(widget.bankDraft!, confirmed: true);
        } catch (_) {
          throw const FormatException(
            'Đã lưu giao dịch vào máy. Vui lòng thử lại để hoàn tất thông báo.',
          );
        }
        ref.invalidate(bankDraftsProvider);
        ref.invalidate(bankCountProvider);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accountState = ref.watch(recordsProvider(Entity.accounts));
    final categoryState = ref.watch(recordsProvider(Entity.categories));
    final allCategories = categoryState.value ?? [];
    final accounts = (accountState.value ?? [])
        .where(
          (a) =>
              !a.flag('is_archived') ||
              a.id == account ||
              a.id == from ||
              a.id == to,
        )
        .toList();
    final categories = allCategories
        .where(
          (c) =>
              (!c.flag('is_archived') || c.id == category) &&
              (c.text('type') == type || c.text('type') == 'both'),
        )
        .toList();
    final peopleState = ref.watch(recordsProvider(Entity.people));
    final people = peopleState.value ?? <Record>[];
    final debtsState = ref.watch(recordsProvider(Entity.debts));
    final allDebts = debtsState.value ?? <Record>[];
    final tagState = ref.watch(recordsProvider(Entity.tags));
    final links = ref.watch(recordsProvider(Entity.transactionTags));
    final tags = tagSuggestions(tagState.value ?? [], links.value ?? []);
    final ready =
        accountState.hasValue &&
        categoryState.hasValue &&
        tagState.hasValue &&
        links.hasValue;

    if (!initialized && accounts.isNotEmpty && ready) {
      initialized = true;
      account ??=
          (widget.bankDraft == null
                  ? accounts.first
                  : accounts
                        .where((a) => a.text('currency') == reviewCurrency)
                        .firstOrNull)
              ?.id;
      from ??= account;
      if (widget.bankDraft == null) category ??= categories.firstOrNull?.id;
      if (widget.record != null) {
        for (final l in links.value!.where(
          (l) => l.text('transaction_id') == widget.record!.id,
        )) {
          final tag = tags.where((t) => t.id == l.text('tag_id')).firstOrNull;
          if (tag != null) selectedTags.add(tag.text('name').toLowerCase());
        }
      } else {
        Future(() async {
          final w = await ref.read(workspaceProvider.future);
          final recent = await w?.repository.recentSelections();
          final a = recent?.$1, c = recent?.$2;
          if (mounted) {
            setState(() {
              if (accounts.any((r) => r.id == a)) account = a;
              if (widget.initialCategory == null &&
                  categories.any((r) => r.id == c)) {
                category = c;
              }
            });
          }
        });
      }
    }

    final selectedCat = allCategories
        .where((c) => c.id == category)
        .firstOrNull;
    final catBehavior = selectedCat?.text('behavior') ?? 'normal';
    final isCongNo =
        catBehavior == 'cong_no_expense' ||
        catBehavior == 'cong_no_income' ||
        catBehavior == 'lending' ||
        selectedCat?.text('name') == 'Công nợ';

    final activeDebts = allDebts
        .where(
          (d) =>
              !d.deleted &&
              d.text('status') == 'active' &&
              d.text('direction') ==
                  (actionTag == 'Thu nợ'
                      ? 'lent'
                      : actionTag == 'Trả nợ'
                      ? 'borrowed'
                      : ''),
        )
        .toList();

    final currency =
        accounts
            .where((a) => a.id == (type == 'transfer' ? from : account))
            .firstOrNull
            ?.text('currency') ??
        'VND';

    return FormDialog(
      title: widget.bankDraft != null
          ? 'Xác nhận giao dịch ngân hàng'
          : widget.record == null
          ? 'Giao dịch mới'
          : 'Chỉnh sửa giao dịch',
      busy: busy,
      saveEnabled: ready,
      error:
          error ??
          (accountState.hasError ||
                  categoryState.hasError ||
                  tagState.hasError ||
                  links.hasError
              ? context.tr("Could not load choices. Close this form and retry.")
              : null),
      save: () => save(
        accounts,
        tags,
        isCongNo: isCongNo,
        people: people,
        debts: allDebts,
      ),
      children: [
        if (widget.bankDraft != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primaryAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colors.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kiểm tra kỹ thông tin trước khi xác nhận. Không có quy đổi tỷ giá.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        // ── Loại giao dịch (Segmented buttons) ─────────────────────────────
        if (!bankReadOnly)
          Container(
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Chi tiêu',
                    icon: Icons.north_rounded,
                    selected: type == 'expense',
                    activeColor: colors.expense,
                    onTap: () => setState(() {
                      type = 'expense';
                      category = null;
                      selectedTags.clear();
                      tagInput.clear();
                      actionTag = null;
                      selectedDebtId = null;
                    }),
                  ),
                ),
                Expanded(
                  child: _TypeButton(
                    label: 'Thu nhập',
                    icon: Icons.south_rounded,
                    selected: type == 'income',
                    activeColor: colors.income,
                    onTap: () => setState(() {
                      type = 'income';
                      category = null;
                      selectedTags.clear();
                      tagInput.clear();
                      actionTag = null;
                      selectedDebtId = null;
                    }),
                  ),
                ),
                Expanded(
                  child: _TypeButton(
                    label: 'Chuyển',
                    icon: Icons.swap_horiz_rounded,
                    selected: type == 'transfer',
                    activeColor: colors.primaryAccent,
                    onTap: () => setState(() {
                      type = 'transfer';
                      category = null;
                      selectedTags.clear();
                      tagInput.clear();
                      actionTag = null;
                      selectedDebtId = null;
                    }),
                  ),
                ),
              ],
            ),
          ),

        // ── Ô nhập số tiền lớn ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.record?.data['bank_source'] case final Map source)
                if (source['original_currency'] == 'USD')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Gốc: ${Money.format(source['original_amount'] as int, 'USD')} · 1 USD = 27,000 VND',
                    ),
                  ),
              Text(
                'Số tiền',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.bankDraft != null)
                    Text(
                      '${widget.bankDraft!.direction == 'income' ? '+' : '−'} ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: widget.bankDraft!.direction == 'income'
                            ? colors.income
                            : colors.expense,
                      ),
                    ),
                  Expanded(
                    child: Semantics(
                      label: context.tr('Amount'),
                      child: TextField(
                        key: const ValueKey('transaction-amount'),
                        controller: amount,
                        inputFormatters: [
                          MoneyInputFormatter(allowNegative: false),
                        ],
                        readOnly: bankReadOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: type == 'income'
                              ? colors.income
                              : type == 'expense'
                              ? colors.expense
                              : colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        autofocus:
                            widget.bankDraft == null && widget.record == null,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currency,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Ngày giao dịch ─────────────────────────────────────────────────
        InkWell(
          onTap: bankReadOnly
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: occurred,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(
                      () => occurred = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        occurred.hour,
                        occurred.minute,
                      ),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: colors.primaryAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày giao dịch',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        context.dateLabel(occurred),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!bankReadOnly)
                  Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
              ],
            ),
          ),
        ),

        // ── Mô tả ──────────────────────────────────────────────────────────
        TextField(
          controller: description,
          readOnly: bankReadOnly,
          decoration: InputDecoration(
            labelText: context.tr('Description'),
            hintText: 'Cà phê, ăn trưa, đổ xăng…',
            prefixIcon: Icon(Icons.edit_note_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),

        // ── Danh mục (cho Thu chi thường) ──────────────────────────────────
        if (type != 'transfer')
          RecordPicker(
            key: ValueKey('category-$type'),
            label: context.tr('Category'),
            value: category,
            records: categories,
            onChanged: (v) => setState(() {
              category = v;
              selectedTags.clear();
              tagInput.clear();
              actionTag = null;
              selectedDebtId = null;
            }),
            optional: false,
          ),

        // ── Phần Công nợ đặc thù ──────────────────────────────────────────
        if (isCongNo) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      size: 16,
                      color: colors.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hành động công nợ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      (type == 'expense'
                              ? ['Cho vay', 'Trả nợ']
                              : ['Thu nợ', 'Vay nợ'])
                          .map(
                            (tag) => ChoiceChip(
                              label: Text(tag),
                              selected: actionTag == tag,
                              onSelected: (_) => setState(() {
                                actionTag = tag;
                                selectedDebtId = null;
                              }),
                            ),
                          )
                          .toList(),
                ),
                if (actionTag == 'Cho vay' || actionTag == 'Vay nợ') ...[
                  const SizedBox(height: 12),
                  PersonPicker(
                    label: 'Người liên quan',
                    value: borrower,
                    records: people,
                    onChanged: (v) => setState(() => borrower = v),
                  ),
                ],
                if ((actionTag == 'Thu nợ' || actionTag == 'Trả nợ') &&
                    activeDebts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  RecordPicker(
                    label: 'Chọn khoản công nợ cần trả/thu',
                    value: selectedDebtId,
                    records: activeDebts,
                    onChanged: (v) => setState(() => selectedDebtId = v),
                    optional: false,
                  ),
                ],
              ],
            ),
          ),
        ],

        // ── Tag 'Mua chung' cho Công nợ chi tiêu ──────────────────────────
        if (isCongNo && type == 'expense')
          Wrap(
            spacing: 6,
            children: tags
                .where(
                  (t) =>
                      t.text('category_id') == category &&
                      TagDisplay.forRecord(t) == 'Mua chung',
                )
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

        // ── Tài khoản thanh toán ───────────────────────────────────────────
        RecordPicker(
          key: ValueKey('account-$type'),
          label: type == 'transfer' ? 'Từ tài khoản' : 'Tài khoản',
          value: type == 'transfer' ? from : account,
          records: accounts,
          onChanged: (v) => setState(() {
            if (type == 'transfer') {
              from = v;
            } else {
              account = v;
            }
          }),
        ),
        if (type == 'transfer')
          RecordPicker(
            label: context.tr('To account'),
            value: to,
            records: accounts,
            onChanged: (v) => setState(() => to = v),
          ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Chưa có tài khoản nào. Vui lòng thêm tài khoản từ Cài đặt → Tài khoản.',
              style: TextStyle(color: colors.expense, fontSize: 12),
            ),
          ),

        // ── Tags cho danh mục thường ───────────────────────────────────────
        if (!isCongNo && category != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thẻ (Tags)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .where(
                      (t) =>
                          tagsForCategory([t], category).isNotEmpty ||
                          selectedTags.contains(t.text('name').toLowerCase()),
                    )
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
              const SizedBox(height: 8),
              TextField(
                controller: tagInput,
                decoration: InputDecoration(
                  labelText: context.tr('Add tags (optional)'),
                  hintText: 'caphe, banbe',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
        ],

        // ── Ghi chú ────────────────────────────────────────────────────────
        TextField(
          controller: note,
          decoration: InputDecoration(
            labelText: context.tr('Notes (optional)'),
            prefixIcon: Icon(Icons.notes_rounded),
          ),
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypeButton — Nút chọn loại giao dịch dạng Segmented
// ─────────────────────────────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? (isDark
                  ? activeColor.withValues(alpha: 0.25)
                  : activeColor.withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? activeColor : colors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeColor : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
