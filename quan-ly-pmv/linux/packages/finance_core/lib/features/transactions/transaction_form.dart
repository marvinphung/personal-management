import '../share_bill/share_bill_controls.dart';
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
import '../share_bill/share_bill_service.dart';
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
      note = TextEditingController();
  String type = 'expense';
  String? reviewCurrency;
  String? account, from, to, category, error, borrower;
  String? actionTag;
  String? selectedDebtId;
  DateTime occurred = DateTime.now();
  final selectedTags = <String>{};
  bool busy = false, initialized = false;

  // UX improvements
  String? _lastExpenseCategory, _lastIncomeCategory;
  bool _showNote = false;
  bool _shareBillEnabled = false;
  int _shareBillPeople = 1;
  int _shareBillPaidPeople = 1, _shareBillMinimumPaid = 1;
  bool _shareLinksLoaded = false, _shareLinked = false;
  String? _selectedShareBillId;

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
      if (note.text.isNotEmpty) _showNote = true;
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
      if (widget.record != null && !_shareLinksLoaded) {
        throw const FormatException(
          'Đang tải liên kết Share Bill, vui lòng thử lại.',
        );
      }
      if (_shareLinked && (!_shareBillEnabled || isCongNo)) {
        throw const FormatException(
          'Giữ liên kết Share Bill khi chỉnh sửa giao dịch này.',
        );
      }
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
      if (_shareBillEnabled && type == 'income') {
        final selected =
            (ref.read(recordsProvider(Entity.categories)).value ?? [])
                .where((c) => c.id == category)
                .firstOrNull;
        if (!_isNhanShareBillCategory(selected)) {
          throw const FormatException(
            'Vui lòng chọn danh mục Nhận share bill.',
          );
        }
      }
      if (_shareBillEnabled &&
          type == 'income' &&
          _selectedShareBillId == null) {
        throw const FormatException('Vui lòng chọn Share Bill chưa hoàn tất.');
      }
      if (_shareBillEnabled &&
          type == 'expense' &&
          !isCongNo &&
          !bankReadOnly) {
        if (_shareBillPeople < 1) {
          throw const FormatException('Số người phải ít nhất là 1.');
        }
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
        final names = {...selectedTags};
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
        } else if (_shareBillEnabled &&
            type == 'expense' &&
            !isCongNo &&
            widget.bankDraft == null) {
          await ShareBillService(repository).saveExpenseWithShareBill(
            transaction: transaction,
            tags: chosen,
            numPeople: _shareBillPeople,
            paidPeople: _shareBillPaidPeople,
          );
        } else if (_shareBillEnabled &&
            _selectedShareBillId != null &&
            type == 'income' &&
            widget.bankDraft == null) {
          await ShareBillService(repository).saveIncomeWithShareBillPayment(
            transaction: transaction,
            tags: chosen,
            shareBillId: _selectedShareBillId!,
            peopleCount: _shareBillPeople,
          );
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _switchType(String newType) {
    if (type == newType || _shareLinked) return;
    if (type == 'expense') _lastExpenseCategory = category;
    if (type == 'income') _lastIncomeCategory = category;
    setState(() {
      type = newType;
      category = newType == 'expense'
          ? _lastExpenseCategory
          : newType == 'income'
          ? _lastIncomeCategory
          : null;
      selectedTags.clear();
      actionTag = null;
      selectedDebtId = null;
      _shareBillEnabled = false;
      _selectedShareBillId = null;
    });
  }

  bool _isNhanShareBillCategory(Record? cat) {
    if (cat == null) return false;
    final name = cat.text('name').toLowerCase();
    return name.contains('nhận share') ||
        name.contains('nhan share') ||
        name.contains('share bill') ||
        cat.text('behavior') == 'share_bill_income';
  }

  List<Record> _topCategories(
    List<Record> categories,
    List<Record> transactions, {
    int limit = 5,
  }) {
    final counts = <String, int>{};
    for (final tx in transactions.where(
      (t) => !t.deleted && t.text('type') == type,
    )) {
      final cid = tx.text('category_id');
      if (cid.isNotEmpty) counts[cid] = (counts[cid] ?? 0) + 1;
    }
    final sorted = List<Record>.from(categories);
    sorted.sort((a, b) {
      final diff = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      return diff != 0 ? diff : a.text('name').compareTo(b.text('name'));
    });
    final top = sorted.take(limit).toList();
    // Ensure current selection is visible
    if (category != null && !top.any((c) => c.id == category)) {
      final cur = categories.where((c) => c.id == category).firstOrNull;
      if (cur != null) top.insert(0, cur);
    }
    return top.take(limit + 1).toList();
  }

  // ── Feature Bubble ─────────────────────────────────────────────────────────

  Widget _buildBubbleButton(
    BuildContext context,
    List<Record> allCategories,
    bool isCongNo,
  ) {
    final congNoExpenseCat = type == 'expense'
        ? allCategories
              .where(
                (c) =>
                    !c.flag('is_archived') &&
                    (c.text('behavior') == 'cong_no_expense' ||
                        c.text('behavior') == 'lending'),
              )
              .firstOrNull
        : null;
    final congNoIncomeCat = type == 'income'
        ? allCategories
              .where(
                (c) =>
                    !c.flag('is_archived') &&
                    c.text('behavior') == 'cong_no_income',
              )
              .firstOrNull
        : null;
    final investExpenseCat = type == 'expense'
        ? allCategories
              .where(
                (c) =>
                    !c.flag('is_archived') &&
                    c.text('behavior') == 'investment_expense',
              )
              .firstOrNull
        : null;
    final investIncomeCat = type == 'income'
        ? allCategories
              .where(
                (c) =>
                    !c.flag('is_archived') &&
                    c.text('behavior') == 'investment_income',
              )
              .firstOrNull
        : null;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.add_circle_outline_rounded),
      tooltip: 'Tính năng đặc biệt',
      onSelected: (value) {
        if (_shareLinked) return;
        switch (value) {
          case 'share_bill':
            setState(() {
              _shareBillEnabled = !_shareBillEnabled;
              if (_shareBillEnabled) {
                actionTag = null;
                selectedDebtId = null;
              }
            });
          case 'cong_no':
            final target = congNoExpenseCat ?? congNoIncomeCat;
            if (target != null) {
              setState(() {
                category = target.id;
                _shareBillEnabled = false;
                _selectedShareBillId = null;
                selectedTags.clear();
                actionTag = null;
                selectedDebtId = null;
              });
            }
          case 'dau_tu':
            final target = investExpenseCat ?? investIncomeCat;
            if (target != null) {
              setState(() {
                category = target.id;
                _shareBillEnabled = false;
                _selectedShareBillId = null;
                selectedTags.clear();
                actionTag = null;
                selectedDebtId = null;
              });
            }
        }
      },
      itemBuilder: (ctx) => [
        if (type == 'expense' && !bankReadOnly)
          PopupMenuItem(
            value: 'share_bill',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _shareBillEnabled && !isCongNo
                    ? Icons.group_rounded
                    : Icons.group_outlined,
              ),
              title: const Text('Chia bill với nhóm'),
              trailing: (_shareBillEnabled && !isCongNo)
                  ? const Icon(Icons.check, size: 16)
                  : null,
            ),
          ),
        if (congNoExpenseCat != null || congNoIncomeCat != null)
          PopupMenuItem(
            value: 'cong_no',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isCongNo ? Icons.handshake_rounded : Icons.handshake_outlined,
              ),
              title: const Text('Công nợ'),
              trailing: isCongNo ? const Icon(Icons.check, size: 16) : null,
            ),
          ),
        if (investExpenseCat != null || investIncomeCat != null)
          const PopupMenuItem(
            value: 'dau_tu',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.trending_up_rounded),
              title: Text('Đầu tư'),
            ),
          ),
      ],
    );
  }

  // ── Category section ───────────────────────────────────────────────────────

  void _showAllCategories(
    BuildContext context,
    List<Record> categories,
    List<Record> allCategories,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollController) {
          final colors = context.colors;
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderProminent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chọn danh mục',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    for (final c in categories)
                      ListTile(
                        selected: c.id == category,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              c.text('name').isNotEmpty
                                  ? c.text('name')[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(c.text('name')),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            category = c.id;
                            selectedTags.clear();
                            actionTag = null;
                            selectedDebtId = null;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    const Divider(),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.primaryAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add,
                          color: colors.primaryAccent,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        'Thêm danh mục mới',
                        style: TextStyle(
                          color: colors.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _addNewCategory(context, allCategories);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addNewCategory(BuildContext context, List<Record> allCategories) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == 'expense' ? 'Danh mục chi tiêu mới' : 'Danh mục thu nhập mới',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            hintText: 'Nhập tên danh mục…',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) =>
              _saveNewCategory(ctx, controller.text, allCategories),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                _saveNewCategory(ctx, controller.text, allCategories),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _saveNewCategory(
    BuildContext ctx,
    String name,
    List<Record> allCategories,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(ctx);
    try {
      await saveAndSync(ref, (repository) async {
        final cat = repository.create(Entity.categories, {
          'name': trimmed,
          'type': type,
          'behavior': 'normal',
          'is_default': false,
          'is_archived': false,
        });
        await repository.save(cat);
        setState(() {
          category = cat.id;
          selectedTags.clear();
          actionTag = null;
          selectedDebtId = null;
        });
      });
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    }
  }

  // ── Tag section ────────────────────────────────────────────────────────────

  void _showAllTags(
    BuildContext context,
    List<Record> allTagsForCategory,
    List<Record> hiddenTags,
  ) {
    final newTagController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final colors = context.colors;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (_, scrollController) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderProminent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Thẻ (Tags)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allTagsForCategory
                          .map(
                            (t) => FilterChip(
                              label: Text('#${TagDisplay.forRecord(t)}'),
                              selected: selectedTags.contains(
                                t.text('name').toLowerCase(),
                              ),
                              onSelected: (v) {
                                setModalState(() {});
                                setState(() {
                                  if (v) {
                                    selectedTags.add(
                                      t.text('name').toLowerCase(),
                                    );
                                  } else {
                                    selectedTags.remove(
                                      t.text('name').toLowerCase(),
                                    );
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTagController,
                            decoration: InputDecoration(
                              labelText: 'Thêm thẻ mới',
                              hintText: 'caphe, banbe…',
                              prefixIcon: const Icon(Icons.tag_rounded),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (v) =>
                                _addTagsFromInput(v, allTagsForCategory),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            _addTagsFromInput(
                              newTagController.text,
                              allTagsForCategory,
                            );
                            newTagController.clear();
                            setModalState(() {});
                          },
                          child: const Text('Thêm'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addTagsFromInput(String input, List<Record> existingTags) {
    final names = input
        .split(RegExp(r'[,#]+'))
        .map(normalizeTagName)
        .where((s) => s.isNotEmpty);
    for (final name in names) {
      final existing = existingTags
          .where((t) => t.text('name').toLowerCase() == name)
          .firstOrNull;
      if (existing != null) {
        setState(() => selectedTags.add(existing.text('name').toLowerCase()));
      } else if (name.isNotEmpty) {
        setState(() => selectedTags.add(name));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cs = Theme.of(context).colorScheme;
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
    final txState = ref.watch(recordsProvider(Entity.transactions));
    final allTxs = txState.value ?? [];
    final tags = tagSuggestions(tagState.value ?? [], links.value ?? []);
    final shareBillState = ref.watch(recordsProvider(Entity.shareBills));
    final sharePaymentsState = ref.watch(
      recordsProvider(Entity.shareBillPayments),
    );
    if (!_shareLinksLoaded &&
        widget.record != null &&
        shareBillState.hasValue &&
        sharePaymentsState.hasValue) {
      _shareLinksLoaded = true;
      final bill = shareBillState.value!
          .where(
            (b) => !b.deleted && b.text('expense_tx_id') == widget.record!.id,
          )
          .firstOrNull;
      final payment = sharePaymentsState.value!
          .where(
            (p) => !p.deleted && p.text('income_tx_id') == widget.record!.id,
          )
          .firstOrNull;
      if (bill != null || payment != null) {
        _shareLinked = true;
        _shareBillEnabled = true;
        _selectedShareBillId = payment?.text('share_bill_id');
        if (bill != null) {
          final receipts = sharePaymentsState.value!
              .where((p) => !p.deleted && p.text('share_bill_id') == bill.id)
              .fold(0, (sum, p) => sum + (p.data['people_count'] as int? ?? 1));
          _shareBillMinimumPaid = receipts + 1;
          _shareBillPaidPeople =
              (bill.data['initial_paid_people'] as int? ?? 1) + receipts;
        }
        _shareBillPeople =
            bill?.money('num_people') ??
            (payment!.data['people_count'] as int? ?? 1);
      }
    }

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

    final activeShareBills = (shareBillState.value ?? [])
        .where(
          (b) =>
              !b.deleted &&
              b.text('currency') == currency &&
              (b.text('status') == 'active' || b.id == _selectedShareBillId),
        )
        .toList();
    final shareIncomeCategory = allCategories
        .where(
          (c) =>
              !c.deleted &&
              !c.flag('is_archived') &&
              c.text('type') == 'income' &&
              _isNhanShareBillCategory(c),
        )
        .firstOrNull;

    // Top categories and tags
    final topCats = _topCategories(categories, allTxs);
    final allTagsForCat = tagsForCategory(tags, category);
    final topTags = allTagsForCat.take(7).toList();
    final hasMoreTags = allTagsForCat.length > 7;

    final shareControls = ShareBillControls(
      income: type == 'income',
      enabled: _shareBillEnabled,
      linked: _shareLinked,
      people: _shareBillPeople,
      paidPeople: _shareBillPaidPeople,
      minimumPaid: _shareBillMinimumPaid,
      onPaidPeople: (v) => setState(() => _shareBillPaidPeople = v),
      bills: activeShareBills,
      billId: _selectedShareBillId,
      onEnabled: (v) => setState(() {
        _shareBillEnabled = v;
        _selectedShareBillId = null;
        _shareBillPeople = 1;
        _shareBillPaidPeople = 1;
        if (v && type == 'income' && shareIncomeCategory != null) {
          category = shareIncomeCategory.id;
          selectedTags.clear();
        }
      }),
      onPeople: (v) => setState(() => _shareBillPeople = v),
      onBill: (v) => setState(() => _selectedShareBillId = v),
    );

    return FormDialog(
      title: widget.bankDraft != null
          ? 'Xác nhận giao dịch ngân hàng'
          : widget.record == null
          ? 'Giao dịch mới'
          : 'Chỉnh sửa giao dịch',
      busy: busy,
      saveEnabled: ready,
      save: () => save(
        accounts,
        tags,
        isCongNo: isCongNo,
        people: people,
        debts: allDebts,
      ),
      appBarActions: [
        if (type != 'transfer')
          _buildBubbleButton(context, allCategories, isCongNo),
      ],
      children: [
        // ── Error display ở trên cùng ─────────────────────────────────────
        if (error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // ── Bank info ────────────────────────────────────────────────────
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
                    'Kiểm tra kỹ thông tin trước khi xác nhận.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Loại giao dịch ───────────────────────────────────────────────
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
                    onTap: () => _switchType('expense'),
                  ),
                ),
                Expanded(
                  child: _TypeButton(
                    label: 'Thu nhập',
                    icon: Icons.south_rounded,
                    selected: type == 'income',
                    activeColor: colors.income,
                    onTap: () => _switchType('income'),
                  ),
                ),
                Expanded(
                  child: _TypeButton(
                    label: 'Chuyển',
                    icon: Icons.swap_horiz_rounded,
                    selected: type == 'transfer',
                    activeColor: colors.primaryAccent,
                    onTap: () => _switchType('transfer'),
                  ),
                ),
              ],
            ),
          ),

        if (type == 'income') shareControls,

        // ── Số tiền ──────────────────────────────────────────────────────
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
                        decoration: const InputDecoration(
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

        // ── Ngày giao dịch ───────────────────────────────────────────────
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

        // ── Mô tả ────────────────────────────────────────────────────────
        TextField(
          controller: description,
          readOnly: bankReadOnly,
          decoration: InputDecoration(
            labelText: context.tr('Description'),
            hintText: 'Cà phê, ăn trưa, đổ xăng…',
            prefixIcon: const Icon(Icons.edit_note_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),

        // ── Danh mục quick-pick ───────────────────────────────────────────
        if (type != 'transfer' && !(type == 'income' && _shareBillEnabled)) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danh mục',
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
                children: [
                  for (final c in topCats)
                    _CategoryChip(
                      record: c,
                      selected: c.id == category,
                      onTap: () => setState(() {
                        category = c.id;
                        selectedTags.clear();
                        actionTag = null;
                        selectedDebtId = null;
                      }),
                    ),
                  ActionChip(
                    label: const Text('Khác'),
                    avatar: const Icon(Icons.expand_more, size: 16),
                    onPressed: () =>
                        _showAllCategories(context, categories, allCategories),
                  ),
                ],
              ),
            ],
          ),
        ],

        // ── Công nợ ──────────────────────────────────────────────────────
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

        if (isCongNo && type == 'expense')
          Wrap(
            spacing: 6,
            children: [
              for (final tag in allTagsForCat.where(
                (t) => TagDisplay.forRecord(t) == 'Mua chung',
              ))
                FilterChip(
                  label: Text('#${TagDisplay.forRecord(tag)}'),
                  selected: selectedTags.contains(
                    tag.text('name').toLowerCase(),
                  ),
                  onSelected: (v) => setState(() {
                    if (v) {
                      selectedTags.add(tag.text('name').toLowerCase());
                    } else {
                      selectedTags.remove(tag.text('name').toLowerCase());
                    }
                  }),
                ),
            ],
          ),

        if (type == 'expense' && !isCongNo && (!bankReadOnly || _shareLinked))
          shareControls,

        // ── Tài khoản ─────────────────────────────────────────────────────
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

        // ── Tags quick-pick ───────────────────────────────────────────────
        if (!isCongNo &&
            category != null &&
            !(type == 'income' && _shareBillEnabled)) ...[
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
                children: [
                  for (final t in topTags)
                    FilterChip(
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
                  ActionChip(
                    label: Text(hasMoreTags ? 'Khác +' : 'Thêm tag'),
                    avatar: const Icon(Icons.tag_rounded, size: 14),
                    onPressed: () => _showAllTags(
                      context,
                      allTagsForCat,
                      allTagsForCat.skip(7).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],

        // ── Ghi chú (icon → expand) ───────────────────────────────────────
        if (!_showNote && note.text.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
              label: const Text('Thêm ghi chú'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => setState(() => _showNote = true),
            ),
          )
        else
          TextField(
            controller: note,
            autofocus: _showNote && note.text.isEmpty,
            decoration: InputDecoration(
              labelText: context.tr('Notes (optional)'),
              prefixIcon: const Icon(Icons.sticky_note_2_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Ẩn ghi chú',
                onPressed: () => setState(() {
                  _showNote = false;
                  note.clear();
                }),
              ),
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
// _CategoryChip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final Record record;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilterChip(
      label: Text(record.text('name')),
      selected: selected,
      selectedColor: colors.primaryAccent.withValues(alpha: 0.15),
      checkmarkColor: colors.primaryAccent,
      onSelected: (_) => onTap(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareBillToggle
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
