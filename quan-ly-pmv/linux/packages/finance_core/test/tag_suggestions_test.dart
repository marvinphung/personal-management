import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/transactions/tag_suggestions.dart';

void main() {
  test('recently used tags precede unused tags with stable name ordering', () {
    Record tag(String name) =>
        Record.create(Entity.tags, 'user', {'name': name}, id: name);
    final old = Record.create(Entity.transactionTags, 'user', {
      'tag_id': 'coffee',
      'updated_at': '2026-09-01T00:00:00Z',
    });
    final recent = Record.create(Entity.transactionTags, 'user', {
      'tag_id': 'university',
      'updated_at': '2026-09-10T00:00:00Z',
    });
    final deleted = Record.create(Entity.transactionTags, 'user', {
      'tag_id': 'books',
      'updated_at': '2026-09-11T00:00:00Z',
      'deleted_at': '2026-09-12T00:00:00Z',
    });
    expect(
      tagSuggestions(
        [tag('books'), tag('coffee'), tag('university')],
        [old, recent, deleted],
      ).map((t) => t.id),
      ['university', 'coffee', 'books'],
    );
  });
}
