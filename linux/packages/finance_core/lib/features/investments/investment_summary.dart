import '../../core/database/record.dart';
import '../../core/utils/tag_display.dart';

class InvestmentSummary {
  final List<Record> transactions;
  final int invested, returned;
  int get difference => returned - invested;
  const InvestmentSummary(this.transactions, this.invested, this.returned);

  factory InvestmentSummary.filter({
    required Iterable<Record> transactions,
    required Iterable<Record> categories,
    required Iterable<Record> tags,
    required Iterable<Record> links,
    required String currency,
    Set<String> kinds = const {},
    DateTime? start,
    DateTime? end,
  }) {
    final categoryIds = categories
        .where(
          (c) =>
              !c.deleted &&
              [
                'investment_expense',
                'investment_income',
              ].contains(c.text('behavior')),
        )
        .map((c) => c.id)
        .toSet();
    final tagIds = tags
        .where(
          (t) =>
              !t.deleted &&
              categoryIds.contains(t.text('category_id')) &&
              kinds.contains(TagDisplay.forRecord(t)),
        )
        .map((t) => t.id)
        .toSet();
    final selectedTransactions = links
        .where((l) => !l.deleted && tagIds.contains(l.text('tag_id')))
        .map((l) => l.text('transaction_id'))
        .toSet();
    final rows =
        transactions.where((t) {
          if (t.deleted ||
              t.text('currency') != currency ||
              !categoryIds.contains(t.text('category_id'))) {
            return false;
          }
          final date = t.date('occurred_at');
          return (start == null || !date.isBefore(start)) &&
              (end == null || date.isBefore(end)) &&
              (kinds.isEmpty || selectedTransactions.contains(t.id));
        }).toList()..sort(
          (a, b) => b.date('occurred_at').compareTo(a.date('occurred_at')),
        );
    return InvestmentSummary(
      rows,
      rows
          .where((t) => t.text('type') == 'expense')
          .fold(0, (s, t) => s + t.money('amount')),
      rows
          .where((t) => t.text('type') == 'income')
          .fold(0, (s, t) => s + t.money('amount')),
    );
  }
}
