import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import 'transaction_form.dart';
import '../debts/debt_screen.dart';

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
    final colors = context.colors;
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
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(context.tr('All')),
                        selected: type.isEmpty,
                        onSelected: (_) => setState(() {
                          type = '';
                          visible = 50;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(context.tr('Expense')),
                        selected: type == 'expense',
                        onSelected: (_) => setState(() {
                          type = 'expense';
                          visible = 50;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(context.tr('Income')),
                        selected: type == 'income',
                        onSelected: (_) => setState(() {
                          type = 'income';
                          visible = 50;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: category.isNotEmpty || tag.isNotEmpty || account.isNotEmpty,
                child: IconButton.filledTonal(
                  tooltip: context.tr('Filter'),
                  icon: const Icon(Icons.filter_list_rounded),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setModalState) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.tr('Filter transactions'),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (category.isNotEmpty || tag.isNotEmpty || account.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            category = '';
                                            tag = '';
                                            account = '';
                                          });
                                          Navigator.pop(ctx);
                                        },
                                        child: Text(context.tr('Reset')),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: account.isEmpty ? null : account,
                                  decoration: InputDecoration(labelText: context.tr('Account')),
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(context.tr('All'))),
                                    for (final a in accounts)
                                      DropdownMenuItem(value: a.id, child: Text(a.text('name'))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => account = v ?? '');
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: category.isEmpty ? null : category,
                                  decoration: InputDecoration(labelText: context.tr('Category')),
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(context.tr('All'))),
                                    for (final c in categories)
                                      DropdownMenuItem(value: c.id, child: Text(c.text('name'))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => category = v ?? '');
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: tag.isEmpty ? null : tag,
                                  decoration: InputDecoration(labelText: context.tr('Tag')),
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(context.tr('All'))),
                                    for (final tg in tags)
                                      DropdownMenuItem(value: tg.id, child: Text(tg.text('name'))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => tag = v ?? '');
                                  },
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(context.tr('Apply')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: (t.text('type') == 'income' ? colors.income : colors.expense).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              t.text('type') == 'income'
                                  ? Icons.arrow_downward_rounded
                                  : (t.text('type') == 'expense'
                                      ? Icons.arrow_upward_rounded
                                      : Icons.swap_horiz_rounded),
                              color: t.text('type') == 'income' ? colors.income : colors.expense,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            t.text('description').isEmpty
                                ? context.tr(t.text('type'))
                                : t.text('description'),
                            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          subtitle: Text(
                            '${label(categories, t.text('category_id'))} ${tagNames(t)}'.trim(),
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          trailing: SizedBox(
                            width: 132,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: MoneyText(
                                  amountMinor: t.money('amount'),
                                  currency: t.text('currency'),
                                  direction: t.text('type'),
                                ),
                              ),
                            ),
                          ),
                          onTap: () => showTransactionDetail(context, t),
                        ),
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
    final debts = ref.watch(recordsProvider(Entity.debts)).value ?? <Record>[];
    final payments =
        ref.watch(recordsProvider(Entity.debtPayments)).value ?? <Record>[];
    final payment = payments
        .where((p) => p.text('linked_transaction_id') == record.id)
        .firstOrNull;
    final linkedDebt = debts
        .where(
          (d) =>
              d.text('linked_transaction_id') == record.id ||
              d.id == payment?.text('debt_id'),
        )
        .firstOrNull;
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
                if (record.text('created_at').isNotEmpty)
                  context.tr('Created'): DateFormat.yMMMd(
                    context.languageCode,
                  ).add_Hm().format(record.date('created_at')),
                if (record.text('updated_at').isNotEmpty)
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
        ] else if (linkedDebt != null)
          FilledButton.icon(
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () => showDebtDetail(context, linkedDebt),
            label: Text(context.tr('Open linked debt')),
          )
        else
          Text(context.tr('Manage through the linked debt.')),
      ],
    );
  }
}
