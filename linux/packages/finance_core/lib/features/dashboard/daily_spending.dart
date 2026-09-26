import '../../core/database/record.dart';
import '../../core/utils/ledger.dart';

/// Local calendar days, exact minor units, including days with no spending.
List<int> dailySpending(
  Iterable<Record> rows,
  DateTime month,
  String currency,
) {
  final days = List.filled(DateTime(month.year, month.month + 1, 0).day, 0);
  for (final row in rows) {
    if (row.deleted ||
        Ledger.isScheduled(row) ||
        row.text('currency') != currency ||
        row.text('purpose') != 'normal' ||
        row.text('type') != 'expense') {
      continue;
    }
    final date = row.date('occurred_at');
    if (date.year == month.year && date.month == month.month) {
      days[date.day - 1] += row.money('amount');
    }
  }
  return days;
}
