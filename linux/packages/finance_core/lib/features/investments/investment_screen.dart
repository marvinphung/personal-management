import 'investment_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tag_display.dart';
import '../transactions/transaction_screen.dart';
import '../transactions/transaction_form.dart';

enum InvestmentTimeFilter { allTime, thisYear, thisMonth }

class InvestmentScreen extends ConsumerStatefulWidget {
  const InvestmentScreen({super.key});

  @override
  ConsumerState<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends ConsumerState<InvestmentScreen> {
  InvestmentTimeFilter _timeFilter = InvestmentTimeFilter.allTime;
  final Set<String> _selectedKinds = {};

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final categories =
        ref.watch(recordsProvider(Entity.categories)).value ?? [];
    final tags = ref.watch(recordsProvider(Entity.tags)).value ?? [];
    final links =
        ref.watch(recordsProvider(Entity.transactionTags)).value ?? [];
    final allTransactions =
        ref.watch(recordsProvider(Entity.transactions)).value ?? [];
    final colors = context.colors;

    // Find Đầu tư categories (both expense and income)
    final investmentCatIds = categories
        .where(
          (c) =>
              !c.flag('is_archived') &&
              (c.text('behavior') == 'investment_expense' ||
                  c.text('behavior') == 'investment_income' ||
                  c.text('name') == 'Đầu tư'),
        )
        .map((c) => c.id)
        .toSet();

    // Investment tags
    final investmentTags = tags
        .where(
          (t) => !t.deleted && investmentCatIds.contains(t.text('category_id')),
        )
        .fold<Map<String, Record>>({}, (map, tag) {
          map.putIfAbsent(TagDisplay.forRecord(tag), () => tag);
          return map;
        })
        .values
        .toList();

    final now = DateTime.now();
    final summary = InvestmentSummary.filter(
      transactions: allTransactions,
      categories: categories,
      tags: tags,
      links: links,
      currency: currency,
      kinds: _selectedKinds,
      start: switch (_timeFilter) {
        InvestmentTimeFilter.allTime => null,
        InvestmentTimeFilter.thisYear => DateTime(now.year),
        InvestmentTimeFilter.thisMonth => DateTime(now.year, now.month),
      },
      end: _timeFilter == InvestmentTimeFilter.allTime
          ? null
          : _timeFilter == InvestmentTimeFilter.thisYear
          ? DateTime(now.year + 1)
          : DateTime(now.year, now.month + 1),
    );
    final investmentTransactions = summary.transactions;
    final totalInvested = summary.invested,
        totalReturned = summary.returned,
        diff = summary.difference;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đầu tư'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm giao dịch'),
              onPressed: () => showTransactionForm(
                context,
                initialCategory: categories
                    .where(
                      (c) =>
                          !c.flag('is_archived') &&
                          c.text('behavior') == 'investment_expense',
                    )
                    .firstOrNull
                    ?.id,
                initialType: 'expense',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Filter Row: Time range segmented control ─────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _timeFilter == InvestmentTimeFilter.allTime,
                  onSelected: (val) {
                    if (val) {
                      setState(
                        () => _timeFilter = InvestmentTimeFilter.allTime,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Năm nay (${now.year})'),
                  selected: _timeFilter == InvestmentTimeFilter.thisYear,
                  onSelected: (val) {
                    if (val) {
                      setState(
                        () => _timeFilter = InvestmentTimeFilter.thisYear,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Tháng này (${now.month}/${now.year})'),
                  selected: _timeFilter == InvestmentTimeFilter.thisMonth,
                  onSelected: (val) {
                    if (val) {
                      setState(
                        () => _timeFilter = InvestmentTimeFilter.thisMonth,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Tag Filter Chips (Multi-select) ──────────────────────────────
          if (investmentTags.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tag in investmentTags) ...[
                    FilterChip(
                      label: Text('#${TagDisplay.forRecord(tag)}'),
                      selected: _selectedKinds.contains(
                        TagDisplay.forRecord(tag),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedKinds.add(TagDisplay.forRecord(tag));
                          } else {
                            _selectedKinds.remove(TagDisplay.forRecord(tag));
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Summary Card: Vốn bỏ vào, Tiền nhận về, Chênh lệch ────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors.primaryAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'TỔNG QUAN ĐẦU TƯ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.north_rounded,
                                  size: 14,
                                  color: colors.expense,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Vốn bỏ vào',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Money.format(totalInvested, currency),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: colors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: colors.borderSubtle,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.south_rounded,
                                  size: 14,
                                  color: colors.income,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Tiền nhận về (gốc+lãi)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Money.format(totalReturned, currency),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: colors.income,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Chênh lệch (Lãi/Lỗ ròng)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${diff >= 0 ? '+' : '−'}${Money.format(diff.abs(), currency)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: diff >= 0 ? colors.income : colors.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Transaction History Header ───────────────────────────────────
          SectionHeader(
            title:
                'Lịch sử giao dịch đầu tư (${investmentTransactions.length})',
          ),

          if (investmentTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 40,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Chưa có giao dịch đầu tư nào trong khoảng thời gian này.',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final t in investmentTransactions)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: TransactionLeadingIcon(type: t.text('type')),
                  title: Text(
                    t.text('description').isEmpty
                        ? (t.text('type') == 'income'
                              ? 'Thu đầu tư'
                              : 'Chi đầu tư')
                        : t.text('description'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _formatDate(t.date('occurred_at')),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
