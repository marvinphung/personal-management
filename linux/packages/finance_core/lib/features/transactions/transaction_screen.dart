import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import 'transaction_form.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: context.tr('Previous month'),
        onPressed: () => ref.read(monthProvider.notifier).move(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Flexible(
        child: Text(
          DateFormat.yMMMM(
            context.languageCode,
          ).format(ref.watch(monthProvider)),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        tooltip: context.tr('Next month'),
        onPressed: () => ref.read(monthProvider.notifier).move(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

String transactionSign(Record r) => switch (r.text('type')) {
  'income' => '+',
  'expense' => '−',
  _ => '↔',
};

class TransactionScreen extends ConsumerStatefulWidget {
  const TransactionScreen({super.key});
  @override
  ConsumerState<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends ConsumerState<TransactionScreen> {
  String query = '', type = '', category = '', tag = '', account = '';
  int visible = 50;
  bool ascending = false;
  int sortColumn = 0;
  @override
  Widget build(BuildContext context) {
    final categories =
            ref.watch(recordsProvider(Entity.categories)).value ?? [],
        tags = ref.watch(recordsProvider(Entity.tags)).value ?? [],
        accounts = ref.watch(recordsProvider(Entity.accounts)).value ?? [],
        links = ref.watch(recordsProvider(Entity.transactionTags)).value ?? [];
    String label(List<Record> rows, String id) =>
        rows.where((r) => r.id == id).firstOrNull?.text('name') ?? '';
    String tagNames(Record t) => links
        .where((l) => l.text('transaction_id') == t.id)
        .map((l) => '#${label(tags, l.text('tag_id'))}')
        .join(' ');
    Widget filter(
      String title,
      String value,
      List<(String, String)> options,
      ValueChanged<String> change,
    ) => SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: title),
        items: [
          DropdownMenuItem(value: '', child: Text(context.tr('All'))),
          for (final o in options)
            DropdownMenuItem(
              value: o.$1,
              child: Text(o.$2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() {
          change(v!);
          visible = 50;
        }),
      ),
    );
    return Column(
      children: [
        const MonthSelector(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.tr(
                'Search description, notes, category or tags',
              ),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() {
              query = v.toLowerCase();
              visible = 50;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                filter(
                  context.tr('Type'),
                  type,
                  TransactionType.values
                      .map((v) => (v.name, context.tr(v.name)))
                      .toList(),
                  (v) => type = v,
                ),
                filter(
                  context.tr('Account'),
                  account,
                  accounts.map((r) => (r.id, r.text('name'))).toList(),
                  (v) => account = v,
                ),
                filter(
                  context.tr('Category'),
                  category,
                  categories.map((r) => (r.id, r.text('name'))).toList(),
                  (v) => category = v,
                ),
                filter(
                  context.tr('Tag'),
                  tag,
                  tags.map((r) => (r.id, r.text('name'))).toList(),
                  (v) => tag = v,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncRecords(
            value: ref.watch(monthTransactionsProvider),
            builder: (rows) {
              final filtered =
                  rows
                      .where(
                        (t) =>
                            (type.isEmpty || t.text('type') == type) &&
                            (account.isEmpty ||
                                [
                                  t.text('account_id'),
                                  t.text('from_account_id'),
                                  t.text('to_account_id'),
                                ].contains(account)) &&
                            (category.isEmpty ||
                                t.text('category_id') == category) &&
                            (tag.isEmpty ||
                                links.any(
                                  (l) =>
                                      l.text('transaction_id') == t.id &&
                                      l.text('tag_id') == tag,
                                )) &&
                            '${t.text('description')} ${t.text('note')} ${label(categories, t.text('category_id'))} ${tagNames(t)}'
                                .toLowerCase()
                                .contains(query),
                      )
                      .toList()
                    ..sort((a, b) {
                      final result = sortColumn == 5
                          ? a.money('amount').compareTo(b.money('amount'))
                          : sortColumn == 1
                          ? a
                                .text('description')
                                .compareTo(b.text('description'))
                          : a
                                .text('occurred_at')
                                .compareTo(b.text('occurred_at'));
                      return ascending ? result : -result;
                    });
              if (filtered.isEmpty) {
                return EmptyState(
                  title: context.tr('No transactions this month'),
                  description: context.tr(
                    'Record your first expense to start tracking your spending.',
                  ),
                  onAdd: () => showTransactionForm(context),
                );
              }
              final shown = filtered.take(visible).toList();
              if (MediaQuery.sizeOf(context).width >= 1000) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: sortColumn,
                          sortAscending: ascending,
                          columns: [
                            for (final (i, title) in [
                              context.tr('Date'),
                              context.tr('Description'),
                              context.tr('Category'),
                              context.tr('Tags'),
                              context.tr('Account'),
                              context.tr('Amount'),
                            ].indexed)
                              DataColumn(
                                label: Text(title),
                                numeric: i == 5,
                                onSort: [0, 1, 5].contains(i)
                                    ? (col, asc) => setState(() {
                                        sortColumn = col;
                                        ascending = asc;
                                      })
                                    : null,
                              ),
                          ],
                          rows: shown
                              .map(
                                (t) => DataRow(
                                  onSelectChanged: (_) =>
                                      showTransactionDetail(context, t),
                                  cells: [
                                    DataCell(
                                      Text(
                                        DateFormat.MMMd(
                                          context.languageCode,
                                        ).format(t.date('occurred_at')),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        t.text('description').isEmpty
                                            ? context.tr(t.text('type'))
                                            : t.text('description'),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        label(
                                          categories,
                                          t.text('category_id'),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(tagNames(t))),
                                    DataCell(
                                      Text(
                                        t.text('type') == 'transfer'
                                            ? '${label(accounts, t.text('from_account_id'))} → ${label(accounts, t.text('to_account_id'))}'
                                            : label(
                                                accounts,
                                                t.text('account_id'),
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${transactionSign(t)} ${Money.format(t.money('amount'), t.text('currency'))}',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (filtered.length > visible)
                        TextButton(
                          onPressed: () => setState(() => visible += 50),
                          child: Text(context.tr('Load more')),
                        ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: shown.length + (filtered.length > visible ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == shown.length) {
                    return TextButton(
                      onPressed: () => setState(() => visible += 50),
                      child: Text(context.tr('Load more')),
                    );
                  }
                  final t = shown[index],
                      date = DateFormat.yMMMd(
                        context.languageCode,
                      ).format(t.date('occurred_at')),
                      previous = index == 0
                          ? ''
                          : DateFormat.yMMMd(
                              context.languageCode,
                            ).format(shown[index - 1].date('occurred_at'));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (date != previous)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            date,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ListTile(
                        title: Text(
                          t.text('description').isEmpty
                              ? context.tr(t.text('type'))
                              : t.text('description'),
                        ),
                        subtitle: Text(
                          '${label(categories, t.text('category_id'))} ${tagNames(t)}',
                        ),
                        trailing: Text(
                          '${transactionSign(t)} ${Money.format(t.money('amount'), t.text('currency'))}',
                        ),
                        onTap: () => showTransactionDetail(context, t),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> showTransactionDetail(BuildContext context, Record transaction) =>
    showDialog<void>(
      context: context,
      builder: (_) => TransactionDetail(record: transaction),
    );

class TransactionDetail extends ConsumerWidget {
  final Record record;
  const TransactionDetail({super.key, required this.record});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(recordsProvider(Entity.accounts)).value ?? [],
        categories = ref.watch(recordsProvider(Entity.categories)).value ?? [],
        tags = ref.watch(recordsProvider(Entity.tags)).value ?? [],
        links = ref.watch(recordsProvider(Entity.transactionTags)).value ?? [];
    String name(List<Record> records, String id) =>
        records.where((r) => r.id == id).firstOrNull?.text('name') ?? '—';
    return AlertDialog(
      title: Text(
        record.text('description').isEmpty
            ? context.tr('Transaction')
            : record.text('description'),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transactionSign(record)} ${Money.format(record.money('amount'), record.text('currency'))}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              for (final pair in {
                if (record.data['installment_group'] != null)
                  context.tr(
                    'Installments',
                  ): '${record.text('installment_number')}/${record.text('installment_count')}',
                context.tr('Type'): context.tr(record.text('type')),
                context.tr('Purpose'): context.tr(record.text('purpose')),
                context.tr('Date'): DateFormat.yMMMd(
                  context.languageCode,
                ).add_Hm().format(record.date('occurred_at')),
                context.tr('Account'): record.text('type') == 'transfer'
                    ? '${name(accounts, record.text('from_account_id'))} → ${name(accounts, record.text('to_account_id'))}'
                    : name(accounts, record.text('account_id')),
                context.tr('Category'): name(
                  categories,
                  record.text('category_id'),
                ),
                context.tr('Tags'): links
                    .where((l) => l.text('transaction_id') == record.id)
                    .map((l) => '#${name(tags, l.text('tag_id'))}')
                    .join(' '),
                context.tr('Note'): record.text('note'),
                context.tr('Created'): DateFormat.yMMMd(
                  context.languageCode,
                ).add_Hm().format(record.date('created_at')),
                context.tr('Updated'): DateFormat.yMMMd(
                  context.languageCode,
                ).add_Hm().format(record.date('updated_at')),
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('${pair.key}: ${pair.value}'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
        if (record.text('purpose') == 'normal') ...[
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context)) {
                try {
                  await saveAndSync(ref, (r) => r.remove(record));
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) message(context, userError(context, e));
                }
              }
            },
            child: Text(context.tr('Delete')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showTransactionForm(context, record: record);
            },
            child: Text(context.tr('Edit')),
          ),
        ] else
          Text(context.tr('Manage through the linked debt.')),
      ],
    );
  }
}
