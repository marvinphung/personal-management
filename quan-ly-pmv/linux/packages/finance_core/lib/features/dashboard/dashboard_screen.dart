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
          final name = cat?.text('name') ?? context.tr('Chưa phân loại');
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
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // ── Month selector ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: MonthSelector(),
              ),
            ),

            // ── Summary card ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SummaryCard(
                balanceMinor: totals.net,
                incomeMinor: totals.income,
                expenseMinor: totals.expense,
                currency: currency,
              ),
            ),

            // ── Secondary metrics: Saving rate + Debts ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: StatMetricTile(
                      label: context.tr('Tỉ lệ tiết kiệm'),
                      value: totals.savingRate,
                      valueColor: totals.net >= 0
                          ? colors.income
                          : colors.expense,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatMetricTile(
                      label: 'Cho vay còn lại',
                      value: Money.format(outstanding('lent'), currency),
                      valueColor: colors.income,
                      onTap: () => context.go('/debts'),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatMetricTile(
                      label: 'Vay nợ còn lại',
                      value: Money.format(outstanding('borrowed'), currency),
                      valueColor: colors.expense,
                      onTap: () => context.go('/debts'),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Daily spending chart ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SpendingChart(
                days: dailySpending(rows, month, currency),
                month: month,
                currency: currency,
              ),
            ),

            // ── Expense by category ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: context.tr('Chi tiêu theo danh mục')),
            ),
            if (categoryTotals.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  context.tr(
                    'Thống kê chi tiêu sẽ hiển thị sau khi bạn ghi khoản đầu tiên.',
                  ),
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              )
            else
              _CategoryBreakdown(
                entries: categoryTotals,
                totalExpense: totals.expense,
                currency: currency,
              ),

            // ── Category chart (pie/bar) ───────────────────────────────────
            if (categoryTotals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CategoryChart(
                  entries: categoryTotals,
                  currency: currency,
                ),
              ),

            // ── Expense by tag ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(title: context.tr('Chi tiêu theo thẻ')),
            ),
            if (tagTotals.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.tr('Chưa có chi tiêu nào được gắn thẻ tháng này.'),
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
              )
            else
              _TagBreakdown(
                entries: tagTotals,
                totalExpense: totals.expense,
                currency: currency,
              ),

            // ── Recent transactions ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: context.tr('Giao dịch gần đây'),
                trailing: rows.isNotEmpty
                    ? TextButton(
                        onPressed: () => context.go('/transactions'),
                        child: Text(
                          context.tr('Xem tất cả'),
                          style: TextStyle(color: colors.primaryAccent),
                        ),
                      )
                    : null,
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => showTransactionForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('Ghi khoản đầu tiên')),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final t in rows.take(8))
                      _RecentTransactionTile(
                        transaction: t,
                        onTap: () => showTransactionDetail(context, t),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryBreakdown
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int totalExpense;
  final String currency;

  const _CategoryBreakdown({
    required this.entries,
    required this.totalExpense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: [
          for (final entry in entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              Money.format(entry.value, currency),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalExpense == 0
                                ? 0
                                : (entry.value / totalExpense).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: colors.borderSubtle,
                            color: colors.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TagBreakdown
// ─────────────────────────────────────────────────────────────────────────────

class _TagBreakdown extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int totalExpense;
  final String currency;

  const _TagBreakdown({
    required this.entries,
    required this.totalExpense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${entry.key}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.primaryAccent,
                                ),
                              ),
                            ),
                            Text(
                              Money.format(entry.value, currency),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalExpense == 0
                                ? 0
                                : (entry.value / totalExpense).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: colors.borderSubtle,
                            color: colors.primaryAccent.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecentTransactionTile
// ─────────────────────────────────────────────────────────────────────────────

class _RecentTransactionTile extends StatelessWidget {
  final Record transaction;
  final VoidCallback onTap;

  const _RecentTransactionTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final colors = context.colors;
    final type = t.text('type');
    final description = t.text('description');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    t.text('purpose') == 'normal'
                        ? context.tr(type)
                        : context.tr('Công nợ / Đầu tư'),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
