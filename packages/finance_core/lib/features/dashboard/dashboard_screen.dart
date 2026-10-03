import 'category_chart.dart';
import 'daily_spending.dart';
import 'spending_chart.dart';
import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/ledger.dart';
import '../../core/utils/money.dart';
import '../transactions/transaction_screen.dart';
import '../transactions/transaction_form.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider),
        month = ref.watch(monthProvider),
        categories = ref.watch(recordsProvider(Entity.categories)).value ?? [],
        tags = ref.watch(recordsProvider(Entity.tags)).value ?? [],
        links = ref.watch(recordsProvider(Entity.transactionTags)).value ?? [],
        debts = ref.watch(recordsProvider(Entity.debts)).value ?? [],
        payments = ref.watch(recordsProvider(Entity.debtPayments)).value ?? [];
    return AsyncRecords(
      value: ref.watch(monthTransactionsProvider),
      builder: (rows) {
        final totals = Ledger.monthly(rows, month, currency),
            spending = rows.where(
              (t) =>
                  t.text('currency') == currency &&
                  t.text('purpose') == 'normal' &&
                  t.text('type') == 'expense' &&
                  !Ledger.isScheduled(t),
            );
        final byCategory = <String, int>{}, byTag = <String, int>{};
        for (final t in spending) {
          final name =
              categories
                  .where((c) => c.id == t.text('category_id'))
                  .firstOrNull
                  ?.text('name') ??
              context.tr('Uncategorized');
          byCategory.update(
            name,
            (v) => v + t.money('amount'),
            ifAbsent: () => t.money('amount'),
          );
          for (final l in links.where(
            (l) => l.text('transaction_id') == t.id,
          )) {
            final tag = tags.where((r) => r.id == l.text('tag_id')).firstOrNull;
            if (tag != null) {
              byTag.update(
                tag.text('name'),
                (v) => v + t.money('amount'),
                ifAbsent: () => t.money('amount'),
              );
            }
          }
        }
        final categoryTotals = byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
            tagTotals = byTag.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        int outstanding(String direction) => debts
            .where(
              (d) =>
                  d.text('currency') == currency &&
                  d.text('direction') == direction &&
                  d.text('status') != 'cancelled',
            )
            .fold(0, (sum, d) => sum + Ledger.remaining(d, payments));
        Widget metric(String title, String value) => SizedBox(
          width: 230,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr(title)),
                  const SizedBox(height: 10),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: MonthSelector(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                metric(
                  context.tr('Income'),
                  Money.format(totals.income, currency),
                ),
                metric(
                  context.tr('Expense'),
                  Money.format(totals.expense, currency),
                ),
                metric(context.tr('Net'), Money.format(totals.net, currency)),
                metric(context.tr('Saving rate'), totals.savingRate),
              ],
            ),
            const SizedBox(height: 24),
            SpendingChart(
              days: dailySpending(rows, month, currency),
              month: month,
              currency: currency,
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Expense by category'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            CategoryChart(entries: categoryTotals, currency: currency),
            if (categoryTotals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.tr(
                    'Your spending breakdown will appear after your first expense.',
                  ),
                ),
              ),
            for (final entry in categoryTotals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    value: totals.expense == 0
                        ? 0
                        : entry.value / totals.expense,
                  ),
                ),
                trailing: Text(Money.format(entry.value, currency)),
              ),
            const SizedBox(height: 20),
            Text(
              context.tr('Expense by tag'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(context.tr('A transaction may appear under several tags.')),
            if (tagTotals.isEmpty)
              Text(context.tr('No tagged expenses this month.')),
            for (final entry in tagTotals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('#${entry.key}'),
                subtitle: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    value: totals.expense == 0
                        ? 0
                        : (entry.value / totals.expense).clamp(0, 1),
                  ),
                ),
                trailing: Text(Money.format(entry.value, currency)),
              ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                metric(
                  'People owe me',
                  Money.format(outstanding('lent'), currency),
                ),
                metric(
                  'I owe',
                  Money.format(outstanding('borrowed'), currency),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Recent transactions'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (rows.isEmpty)
              TextButton.icon(
                onPressed: () => showTransactionForm(context),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Record your first expense')),
              ),
            for (final t in rows.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t.text('description').isEmpty
                      ? context.tr(t.text('type'))
                      : t.text('description'),
                ),
                subtitle: Text(
                  t.text('purpose') == 'normal'
                      ? context.tr(t.text('type'))
                      : context.tr('Debt cash movement'),
                ),
                trailing: Text(
                  '${transactionSign(t)} ${Money.format(t.money('amount'), t.text('currency'))}',
                ),
                onTap: () => showTransactionDetail(context, t),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
