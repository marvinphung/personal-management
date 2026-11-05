import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/tag_display.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr('Tháng trước'),
          onPressed: () => ref.read(monthProvider.notifier).move(-1),
          icon: Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
        ),
        Flexible(
          child: Text(
            DateFormat.yMMMM(
              context.languageCode,
            ).format(ref.watch(monthProvider)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: context.tr('Tháng sau'),
          onPressed: () => ref.read(monthProvider.notifier).move(1),
          icon: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ),
      ],
    );
  }
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
    final colors = context.colors;

    String label(List<Record> rows, String id) =>
        rows.where((r) => r.id == id).firstOrNull?.text('name') ?? '';
    String tagNames(Record t) => links
        .where((l) => l.text('transaction_id') == t.id)
        .map(
          (l) =>
              '#${TagDisplay.forRecord(tags.where((t) => t.id == l.text('tag_id')).firstOrNull)}',
        )
        .join(' ');

    Widget filterChip(
      String title,
      String value,
      List<(String, String)> options,
      ValueChanged<String> change,
    ) => SizedBox(
      width: 148,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: title,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(context.tr('Tất cả'))),
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
        // Month selector
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: MonthSelector(),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.tr('Tìm mô tả, ghi chú, danh mục, thẻ…'),
              prefixIcon: Icon(Icons.search, color: colors.textMuted),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (v) => setState(() {
              query = v.toLowerCase();
              visible = 50;
            }),
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                filterChip(
                  context.tr('Loại'),
                  type,
                  TransactionType.values
                      .map((v) => (v.name, context.tr(v.name)))
                      .toList(),
                  (v) => type = v,
                ),
                filterChip(
                  context.tr('Tài khoản'),
                  account,
                  accounts.map((r) => (r.id, r.text('name'))).toList(),
                  (v) => account = v,
                ),
                filterChip(
                  context.tr('Danh mục'),
                  category,
                  categories.map((r) => (r.id, r.text('name'))).toList(),
                  (v) => category = v,
                ),
                filterChip(
                  context.tr('Thẻ'),
                  tag,
                  tags.map((r) => (r.id, TagDisplay.forRecord(r))).toList(),
                  (v) => tag = v,
                ),
              ],
            ),
          ),
        ),

        // Transaction list
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
                  title: context.tr('Không có giao dịch'),
                  description: context.tr(
                    'Record your first expense to start tracking your spending.',
                  ),
                  icon: Icons.receipt_long_outlined,
                  onAdd: () => showTransactionForm(context),
                );
              }

              final shown = filtered.take(visible).toList();

              // Wide screen: DataTable
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
                              context.tr('Ngày'),
                              context.tr('Mô tả'),
                              context.tr('Danh mục'),
                              context.tr('Thẻ'),
                              context.tr('Tài khoản'),
                              context.tr('Số tiền'),
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
                          child: Text(context.tr('Tải thêm')),
                        ),
                    ],
                  ),
                );
              }

              // Mobile: grouped list by date
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: shown.length + (filtered.length > visible ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == shown.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextButton(
                        onPressed: () => setState(() => visible += 50),
                        child: Text(context.tr('Tải thêm')),
                      ),
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
                      if (date != previous) DateGroupHeader(date: date),
                      _TransactionListTile(
                        transaction: t,
                        categoryName: label(categories, t.text('category_id')),
                        tagNames: tagNames(t),
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

// ─────────────────────────────────────────────────────────────────────────────
// _TransactionListTile — tile riêng cho mỗi giao dịch trong danh sách mobile
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionListTile extends StatelessWidget {
  final Record transaction;
  final String categoryName;
  final String tagNames;
  final VoidCallback onTap;

  const _TransactionListTile({
    required this.transaction,
    required this.categoryName,
    required this.tagNames,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final colors = context.colors;
    final type = t.text('type');
    final description = t.text('description');
    final subtitle = [
      categoryName,
      tagNames,
    ].where((s) => s.isNotEmpty).join('  ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            TransactionLeadingIcon(type: type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description.isEmpty ? context.tr(type) : description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MoneyText(
              amountMinor: t.money('amount'),
              currency: t.text('currency'),
              direction: type,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// showTransactionDetail
// ─────────────────────────────────────────────────────────────────────────────

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
    final colors = context.colors;

    String name(List<Record> records, String id) =>
        records.where((r) => r.id == id).firstOrNull?.text('name') ?? '—';

    final type = record.text('type');
    final tagList = links
        .where((l) => l.text('transaction_id') == record.id)
        .map(
          (l) =>
              '#${TagDisplay.forRecord(tags.where((t) => t.id == l.text('tag_id')).firstOrNull)}',
        )
        .join(' ');

    return AlertDialog(
      title: Text(
        record.text('description').isEmpty
            ? context.tr('Giao dịch')
            : record.text('description'),
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount
              MoneyText(
                amountMinor: record.money('amount'),
                currency: record.text('currency'),
                direction: type,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Details
              _DetailRow(label: context.tr('Loại'), value: context.tr(type)),
              _DetailRow(
                label: context.tr('Ngày'),
                value: DateFormat.yMMMd(
                  context.languageCode,
                ).add_Hm().format(record.date('occurred_at')),
              ),
              _DetailRow(
                label: context.tr('Tài khoản'),
                value: type == 'transfer'
                    ? '${name(accounts, record.text('from_account_id'))} → ${name(accounts, record.text('to_account_id'))}'
                    : name(accounts, record.text('account_id')),
              ),
              if (type != 'transfer') ...[
                _DetailRow(
                  label: context.tr('Danh mục'),
                  value: name(categories, record.text('category_id')),
                ),
              ],
              if (tagList.isNotEmpty)
                _DetailRow(label: context.tr('Thẻ'), value: tagList),
              if (record.text('note').isNotEmpty)
                _DetailRow(
                  label: context.tr('Ghi chú'),
                  value: record.text('note'),
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
            style: TextButton.styleFrom(foregroundColor: colors.expense),
            child: Text(context.tr('Xoá')),
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
            label: Text(context.tr('Xem công nợ liên kết')),
          )
        else
          Text(
            context.tr('Quản lý qua khoản công nợ liên kết.'),
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetailRow — hàng chi tiết trong dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
