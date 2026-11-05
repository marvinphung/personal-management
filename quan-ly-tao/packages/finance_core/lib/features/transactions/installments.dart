import 'dart:math' show min;
import 'package:uuid/uuid.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

/// Persist dated installments together: no scheduler or second device generation.
class Installments {
  static List<DateTime> dates(DateTime purchase, int months, int day) {
    if (months < 1 || months > 60 || day < 1 || day > 31) {
      throw const FormatException('Choose 1–60 months and a day from 1–31');
    }
    return List.generate(months, (i) {
      final first = DateTime(purchase.year, purchase.month + i + 1);
      return DateTime(
        first.year,
        first.month,
        min(day, DateTime(first.year, first.month + 1, 0).day),
      );
    });
  }

  static Future<void> save(
    FinanceRepository repo,
    Record template,
    List<Record> tags, {
    required int months,
    required int day,
  }) async {
    if (template.text('type') != 'expense' ||
        template.text('purpose') != 'normal') {
      throw const FormatException('Installments require a normal expense');
    }
    final schedule = dates(template.date('occurred_at'), months, day);
    final rows = <Record>[];
    for (final tag in tags) {
      if (await repo.db.get(Entity.tags, tag.id) == null) rows.add(tag);
    }
    for (var i = 0; i < schedule.length; i++) {
      final id = const Uuid().v5(
        Namespace.url.value,
        'installment:${template.id}:$i',
      );
      rows.add(
        template.patch({
          'id': id,
          'occurred_at': schedule[i].toUtc().toIso8601String(),
          'installment_group': template.id,
          'installment_number': i + 1,
          'installment_count': months,
        }),
      );
      for (final tag in tags) {
        rows.add(
          repo.create(Entity.transactionTags, {
            'transaction_id': id,
            'tag_id': tag.id,
          }, id: const Uuid().v5(Namespace.url.value, 'finance:$id:${tag.id}')),
        );
      }
    }
    // Limits one atomic operation to 100 rows.
    if (rows.length > 100) {
      throw const FormatException(
        'Too many installments and tags; reduce months or tags',
      );
    }
    await repo.saveBatch(rows, importKey: 'installment:${template.id}');
  }
}
