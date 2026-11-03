import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/ledger.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tag_display.dart';
import '../transactions/transaction_form.dart';
import '../transactions/transaction_screen.dart';
import 'category_chart.dart';
import 'daily_spending.dart';
import 'spending_chart.dart';

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
    final colors = context.colors;

    return AsyncRecords(
      value: ref.watch(monthTransactionsProvider),
      builder: (rows) {
        final totals = Ledger.monthly(rows, month, currency);
        // Apply the same totals policy to category/tag breakdowns.
        final spending = rows.where(
          (t) =>
              t.text('currency') == currency &&
              t.text('type') == 'expense' &&
              Ledger.countsInTotals(t),
        );

        final byCategory = <String, int>{}, byTag = <String, int>{};
        for (final t in spending) {
          final cat = categories
              .where((c) => c.id == t.text('category_id'))
              .firstOrNull;
          final name = cat?.text('name') ?? context.tr('Uncategorized');
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
              final tagLabel = TagDisplay.forRecord(tag);
              byTag.update(
                tagLabel,
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
                  d.text('status') != 'cancelled' &&
                  d.text('status') != 'completed',
            )
            .fold(0, (sum, d) => sum + Ledger.remaining(d, payments));

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Month selector
            const Align(
              alignment: Alignment.centerLeft,
              child: MonthSelector(),
            ),
            const SizedBox(height: 12),

            // Full-width Summary Card
            SummaryCard(
              balanceMinor: totals.net,
              incomeMinor: totals.income,
              expenseMinor: totals.expense,
              currency: currency,
            ),
            const SizedBox(height: 12),

            // Secondary metrics row: Saving rate & Debts
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Saving rate'),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totals.savingRate,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: totals.net >= 0
                                ? colors.income
                                : colors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/debts'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cho vay còn lại',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(outstanding('lent'), currency),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/debts'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vay nợ còn lại',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(outstanding('borrowed'), currency),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Daily Spending Chart
            SpendingChart(
              days: dailySpending(rows, month, currency),
              month: month,
              currency: currency,
            ),
            const SizedBox(height: 20),

            // Expense by category
            SectionHeader(title: context.tr('Expense by category')),
            CategoryChart(entries: categoryTotals, currency: currency),
            if (categoryTotals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  context.tr(
                    'Your spending breakdown will appear after your first expense.',
                  ),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            for (final entry in categoryTotals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LinearProgressIndicator(
                    value: totals.expense == 0
                        ? 0
                        : entry.value / totals.expense,
                    backgroundColor: colors.borderSubtle,
                    color: colors.primaryAccent,
                  ),
                ),
                trailing: Text(
                  Money.format(entry.value, currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Expense by tag
            SectionHeader(title: context.tr('Expense by tag')),
            if (tagTotals.isEmpty)
              Text(
                context.tr('No tagged expenses this month.'),
                style: TextStyle(color: colors.textMuted),
              ),
            for (final entry in tagTotals)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '#${entry.key}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LinearProgressIndicator(
                    value: totals.expense == 0
                        ? 0
                        : (entry.value / totals.expense).clamp(0, 1),
                    backgroundColor: colors.borderSubtle,
                    color: colors.primaryAccent,
                  ),
                ),
                trailing: Text(
                  Money.format(entry.value, currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Recent transactions
            SectionHeader(
              title: context.tr('Recent transactions'),
              trailing: rows.isNotEmpty
                  ? TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: Text(
                        context.tr('View all'),
                        style: TextStyle(color: colors.primaryAccent),
                      ),
                    )
                  : null,
            ),
            if (rows.isEmpty)
              TextButton.icon(
                onPressed: () => showTransactionForm(context),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Record your first expense')),
              ),
            for (final t in rows.take(8))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (t.text('type') == 'income'
                                  ? colors.income
                                  : colors.expense)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      t.text('type') == 'income'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: t.text('type') == 'income'
                          ? colors.income
                          : colors.expense,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    t.text('description').isEmpty
                        ? context.tr(t.text('type'))
                        : t.text('description'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    t.text('purpose') == 'normal'
                        ? context.tr(t.text('type'))
                        : context.tr('Debt cash movement'),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  trailing: MoneyText(
                    amountMinor: t.money('amount'),
                    currency: t.text('currency'),
                    direction: t.text('type'),
                  ),
                  onTap: () => showTransactionDetail(context, t),
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
