import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import 'tag_suggestions.dart';

Future<void> showTransactionForm(BuildContext context, {Record? record}) =>
    showDialog<void>(
      context: context,
      builder: (_) => TransactionForm(record: record),
    );

class TransactionForm extends ConsumerStatefulWidget {
  final Record? record;
  const TransactionForm({super.key, this.record});
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final amount = TextEditingController(),
      description = TextEditingController(),
      note = TextEditingController(),
      tagInput = TextEditingController();
  String type = 'expense';
  String? account, from, to, category, error;
  DateTime occurred = DateTime.now();
  final selectedTags = <String>{};
  bool busy = false, initialized = false;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      amount.text = Money.input(r.money('amount'), r.text('currency'));
      description.text = r.text('description');
      note.text = r.text('note');
      type = r.text('type');
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

  Future<void> save(List<Record> accounts, List<Record> tags) async {
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
              .split(RegExp(r'[,\s]+'))
              .map(
                (s) => s.replaceFirst(RegExp(r'^#'), '').trim().toLowerCase(),
              )
              .where((s) => s.isNotEmpty),
        };
        for (final name in names) {
          chosen.add(
            tags
                    .where((t) => t.text('name').toLowerCase() == name)
                    .firstOrNull ??
                repository.create(Entity.tags, {'name': name}),
          );
        }
        await repository.saveTransaction(transaction, chosen);
        await repository.rememberSelections(picked.id, category);
      });
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
      account ??= accounts.first.id;
      from ??= accounts.first.id;
      category ??= categories.firstOrNull?.id;
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
    return FormDialog(
      title: widget.record == null
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
      save: () => save(accounts, tags),
      children: [
        TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: context.tr('Amount'),
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
          selected: {type},
          onSelectionChanged: (v) => setState(() {
            type = v.first;
            category = null;
          }),
        ),
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
            onChanged: (v) => setState(() => category = v),
            optional: true,
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
        TextField(
          controller: tagInput,
          decoration: InputDecoration(
            labelText: context.tr('Tags'),
            hintText: '#coffee #friends',
          ),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          spacing: 6,
          children: tags
              .where(
                (t) =>
                    tagInput.text.isEmpty ||
                    t.text('name').contains(tagInput.text.replaceAll('#', '')),
              )
              .take(8)
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
        ExpansionTile(
          title: Text(context.tr('Date & note')),
          tilePadding: EdgeInsets.zero,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(context.dateLabel(occurred, time: true)),
              onPressed: () async {
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
