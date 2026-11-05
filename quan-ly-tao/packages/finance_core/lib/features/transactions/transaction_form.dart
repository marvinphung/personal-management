import 'installments.dart';
import '../debts/debt_service.dart';
import '../catalog/catalog_screen.dart';
import '../bank_import/bank_draft.dart';
import '../bank_import/bank_confirmation.dart';
import '../bank_import/bank_draft_repository.dart';
import '../bank_import/bank_providers.dart';
import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import 'tag_suggestions.dart';
import '../../core/utils/tag_name.dart';

Future<void> showTransactionForm(
  BuildContext context, {
  Record? record,
  String? defaultType,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => TransactionForm(record: record, defaultType: defaultType),
    );

class TransactionForm extends ConsumerStatefulWidget {
  final Record? record;
  final BankDraft? bankDraft;
  final String? defaultType;
  const TransactionForm({super.key, this.record, this.bankDraft, this.defaultType});
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final amount = TextEditingController(),
      description = TextEditingController(),
      note = TextEditingController(),
      tagInput = TextEditingController();
  String type = 'expense';
  bool installments = false;
  int installmentMonths = 6, installmentDay = 24;
  Record? installmentTemplate;
  String? reviewCurrency;
  String? account, from, to, category, error, borrower;
  DateTime occurred = DateTime.now();
  final selectedTags = <String>{};
  bool busy = false, initialized = false;

  bool get isBank => widget.record?.text('source') == 'bank';

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      amount.text = Money.input(r.money('amount'), r.text('currency'));
      description.text = r.text('description');
      note.text = r.text('note');
      type = r.text('type');
      if (widget.bankDraft != null) reviewCurrency = r.text('currency');
      account = r.data['account_id'];
      from = r.data['from_account_id'];
      to = r.data['to_account_id'];
      category = r.data['category_id'];
      occurred = r.date('occurred_at');
    } else if (widget.defaultType != null) {
      type = widget.defaultType!;
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
    bool lending = false,
    List<Record> people = const [],
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
      await saveAndSync(ref, (repository) async {
        final values = {
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
            tags
                    .where((t) => t.text('name').toLowerCase() == name)
                    .firstOrNull ??
                repository.create(Entity.tags, {
                  'name': name,
                  'category_id': category,
                }),
          );
        }
        final person = lending
            ? people.where((p) => p.id == borrower).firstOrNull
            : null;
        if (lending && person == null) {
          throw const FormatException('Create or select a person first');
        }
        if (widget.bankDraft != null) {
          await BankConfirmation.save(
            repository,
            widget.bankDraft!,
            transaction,
            chosen,
            borrower: person,
          );
        } else if (lending) {
          await DebtService(
            repository,
          ).saveLendingTransaction(transaction, person!, chosen);
        } else if (installments && type == 'expense') {
          installmentTemplate ??= transaction;
          await Installments.save(
            repository,
            transaction.patch({'id': installmentTemplate!.id}),
            chosen,
            months: installmentMonths,
            day: installmentDay,
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
            'Transaction saved locally. Retry to close the draft.',
          );
        }
        ref.invalidate(bankDraftsProvider);
        ref.invalidate(bankCountProvider);
      }
      if (mounted) {
        Navigator.pop(context);
        message(
          context,
          context.tr('Saved locally. Sync will run when connected.'),
        );
      }
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
    final accounts = (accountState.value ?? [])
        .where(
          (a) =>
              !a.flag('is_archived') ||
              a.id == account ||
              a.id == from ||
              a.id == to,
        )
        .toList();
    final categories = (categoryState.value ?? [])
        .where(
          (c) =>
              (!c.flag('is_archived') || c.id == category) &&
              (c.text('type') == type || c.text('type') == 'both'),
        )
        .toList();
    final peopleState = ref.watch(recordsProvider(Entity.people));
    final people = peopleState.value ?? <Record>[];
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
              if (categories.any((r) => r.id == c)) category = c;
            });
          }
        });
      }
    }
    final isLending =
        type == 'expense' &&
        categories.any(
          (c) => c.id == category && c.text('behavior') == 'lending',
        );
    return FormDialog(
      title: widget.bankDraft != null
          ? context.tr('Confirm bank transaction')
          : widget.record == null
          ? context.tr('New transaction')
          : context.tr('Edit transaction'),
      busy: busy,
      saveEnabled: ready && (!isLending || peopleState.hasValue),
      error:
          error ??
          (accountState.hasError ||
                  categoryState.hasError ||
                  tagState.hasError ||
                  links.hasError ||
                  (isLending && peopleState.hasError)
              ? context.tr("Could not load choices. Close this form and retry.")
              : null),
      save: () => save(accounts, tags, lending: isLending, people: people),
      children: [
        if (widget.bankDraft != null) ...[
          Text(
            context.tr(
              'Review every field before confirming. No currency conversion is performed.',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: reviewCurrency,
            decoration: InputDecoration(labelText: context.tr('Currency')),
            items: const [
              DropdownMenuItem(value: 'VND', child: Text('VND')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => reviewCurrency = value),
          ),
          Text(
            context.tr('Account currency: {currency}', {
              'currency':
                  accounts
                      .where(
                        (a) => a.id == (type == 'transfer' ? from : account),
                      )
                      .firstOrNull
                      ?.text('currency') ??
                  '—',
            }),
          ),
          if (type == 'unknown')
            Text(context.tr('Choose income, expense or transfer.')),
        ],
        if (isBank)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('Giao dịch ngân hàng: Số tiền, chiều và thời gian là cố định.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: amount,
          autofocus: !isBank,
          readOnly: isBank,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: context.tr(
              installments && type == 'expense' ? 'Monthly payment' : 'Amount',
            ),
            hintText: context.tr('45000 or 45k'),
          ),
          textInputAction: TextInputAction.next,
        ),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'expense', label: Text(context.tr('Expense'))),
            ButtonSegment(value: 'income', label: Text(context.tr('Income'))),
            ButtonSegment(
              value: 'transfer',
              label: Text(context.tr('Transfer')),
            ),
          ],
          emptySelectionAllowed: type == 'unknown',
          selected: type == 'unknown' ? <String>{} : {type},
          onSelectionChanged: isBank ? null : (v) => setState(() {
            type = v.isEmpty ? 'unknown' : v.first;
            category = null;
            selectedTags.clear();
            tagInput.clear();
          }),
        ),

        if (widget.record == null && type == 'expense' && !isLending) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Installments')),
            value: installments,
            onChanged: busy
                ? null
                : (v) => setState(() => installments = v ?? false),
          ),
          if (installments) ...[
            DropdownButtonFormField<int>(
              initialValue: installmentMonths,
              decoration: InputDecoration(
                labelText: context.tr('Number of months'),
              ),
              items: List.generate(
                60,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() => installmentMonths = v!),
            ),
            DropdownButtonFormField<int>(
              initialValue: installmentDay,
              decoration: InputDecoration(labelText: context.tr('Payment day')),
              items: List.generate(
                31,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() => installmentDay = v!),
            ),
            Text(
              context.tr('First payment: {date}', {
                'date': context.dateLabel(
                  Installments.dates(
                    occurred,
                    installmentMonths,
                    installmentDay,
                  ).first,
                ),
              }),
            ),
            Text(
              context.tr(
                'Enter the monthly payment. Short months use their last day. Future payments do not reduce your current balance.',
              ),
            ),
          ],
        ],
        TextField(
          controller: description,
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
              installments = false;
              selectedTags.clear();
              tagInput.clear();
            }),
            optional: true,
          ),
        if (isLending) ...[
          Text(
            context.tr(
              'This creates a linked debt and is excluded from spending.',
            ),
          ),
          RecordPicker(
            label: context.tr('Borrower'),
            value: borrower,
            records: people,
            onChanged: (v) => setState(() => borrower = v),
          ),
          TextButton.icon(
            onPressed: () => showCatalogForm(context, Entity.people),
            icon: const Icon(Icons.person_add_alt),
            label: Text(context.tr('Add person')),
          ),
        ],
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
        Text(context.tr('Tags')),
        if (category == null)
          Text(context.tr('Choose a category to see its tags')),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: tags
              .where(
                (t) =>
                    tagsForCategory([t], category).isNotEmpty ||
                    selectedTags.contains(t.text('name').toLowerCase()),
              )
              .map(
                (t) => FilterChip(
                  label: Text('#${t.text('name')}'),
                  selected: selectedTags.contains(t.text('name').toLowerCase()),
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
        if (category != null)
          TextField(
            controller: tagInput,
            decoration: InputDecoration(
              labelText: context.tr('Add tags (optional)'),
              hintText: '#caphe, #antrua',
            ),
          ),
        ExpansionTile(
          title: Text(context.tr('Date & note')),
          tilePadding: EdgeInsets.zero,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(context.dateLabel(occurred, time: true)),
              onPressed: isBank
                  ? null
                  : () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: occurred,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(occurred),
                  );
                  if (mounted) {
                    setState(
                      () => occurred = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        time?.hour ?? occurred.hour,
                        time?.minute ?? occurred.minute,
                      ),
                    );
                  }
                }
              },
            ),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: context.tr('Note')),
            ),
          ],
        ),
      ],
    );
  }
}
