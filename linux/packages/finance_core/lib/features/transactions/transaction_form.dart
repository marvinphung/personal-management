import '../catalog/person_picker.dart';
import '../../core/utils/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
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
        throw const FormatException('Create or select an account first');
      }
      if (reviewCurrency != null && reviewCurrency != picked.text('currency')) {
        throw const FormatException('Account currency does not match');
      }
      final value = Money.parse(amount.text, currency: picked.text('currency'));
      if (type != 'transfer' && category == null) {
        throw const FormatException('Choose a category');
      }
      if (isCongNo && actionTag == null) {
        throw const FormatException('Chọn hành động công nợ');
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
            throw const FormatException('This tag belongs to another category');
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
                'Vui lòng chọn khoản công nợ cần thanh toán',
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
            'Transaction saved locally. Retry to close the draft.',
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

    return FormDialog(
      title: widget.bankDraft != null
          ? context.tr('Confirm bank transaction')
          : widget.record == null
          ? context.tr('New transaction')
          : context.tr('Edit transaction'),
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
          Text(
            context.tr(
              'Review every field before confirming. No currency conversion is performed.',
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: amount,
          inputFormatters: [MoneyInputFormatter(allowNegative: false)],
          readOnly: bankReadOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('Amount'),
            prefixText: widget.bankDraft != null
                ? '${widget.bankDraft!.direction == 'income' ? '+' : '−'} '
                : null,
            suffixText: accounts
                .where((a) => a.id == (type == 'transfer' ? from : account))
                .firstOrNull
                ?.text('currency'),
          ),
          autofocus: widget.bankDraft == null && widget.record == null,
          textInputAction: TextInputAction.next,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Date')),
          subtitle: Text(context.dateLabel(occurred)),
          trailing: const Icon(Icons.calendar_today),
          onTap: bankReadOnly
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: occurred,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => occurred = picked);
                },
        ),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: InputDecoration(labelText: context.tr('Type')),
          items: [
            DropdownMenuItem(
              value: 'expense',
              child: Text(context.tr('Expense')),
            ),
            DropdownMenuItem(
              value: 'income',
              child: Text(context.tr('Income')),
            ),
            DropdownMenuItem(
              value: 'transfer',
              child: Text(context.tr('Transfer')),
            ),
          ],
          onChanged: bankReadOnly
              ? null
              : (v) => setState(() {
                  type = v!;
                  category = null;
                  selectedTags.clear();
                  tagInput.clear();
                  actionTag = null;
                  selectedDebtId = null;
                }),
        ),
        TextField(
          controller: description,
          readOnly: bankReadOnly,
          decoration: InputDecoration(
            labelText: context.tr('Description'),
            hintText: context.tr('Coffee'),
          ),
          textInputAction: TextInputAction.next,
        ),
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
        if (isCongNo) ...[
          const SizedBox(height: 8),
          Text(
            'Hành động công nợ',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            PersonPicker(
              label: context.tr('Người liên quan'),
              value: borrower,
              records: people,
              onChanged: (v) => setState(() => borrower = v),
            ),
          ],
          if ((actionTag == 'Thu nợ' || actionTag == 'Trả nợ') &&
              activeDebts.isNotEmpty) ...[
            const SizedBox(height: 8),
            RecordPicker(
              label: 'Chọn danh sách công nợ',
              value: selectedDebtId,
              records: activeDebts,
              onChanged: (v) => setState(() => selectedDebtId = v),
              optional: false,
            ),
          ],
        ],
        if (isCongNo && type == 'expense')
          Wrap(
            spacing: 4,
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
        RecordPicker(
          key: ValueKey('account-$type'),
          label: type == 'transfer'
              ? context.tr('From account')
              : context.tr('Account'),
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
          Text(
            context.tr(
              'Add an account from More → Accounts before recording a transaction.',
            ),
          ),
        if (!isCongNo && category != null) ...[
          Text(context.tr('Tags')),
          Wrap(
            spacing: 4,
            runSpacing: 4,
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
          TextField(
            controller: tagInput,
            decoration: InputDecoration(
              labelText: context.tr('Add tags (optional)'),
              hintText: 'coffee, friends',
            ),
            textInputAction: TextInputAction.next,
          ),
        ],
        TextField(
          controller: note,
          decoration: InputDecoration(
            labelText: context.tr('Notes (optional)'),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
