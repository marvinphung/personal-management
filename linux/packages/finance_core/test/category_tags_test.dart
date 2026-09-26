import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/utils/tag_name.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/transactions/tag_suggestions.dart';

void main() {
  test(
    'tags require an owned category and preserve the relation offline',
    () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final repo = FinanceRepository(db, 'user');
      final category = repo.create(Entity.categories, {'name': 'Ăn uống'});
      await repo.save(category);
      await expectLater(
        repo.save(repo.create(Entity.tags, {'name': 'caphe'})),
        throwsFormatException,
      );
      await expectLater(
        repo.save(
          repo.create(Entity.tags, {'name': 'caphe', 'category_id': 'foreign'}),
        ),
        throwsFormatException,
      );
      final tag = repo.create(Entity.tags, {
        'name': 'caphe',
        'category_id': category.id,
      });
      await repo.save(tag);
      expect(
        (await db.list(Entity.tags)).single.text('category_id'),
        category.id,
      );
      expect(
        (await db.pending()).last.rows.single.text('category_id'),
        category.id,
      );
    },
  );

  test('Vietnamese tags become a compact unaccented slug', () {
    expect(normalizeTagName(' #Ăn trưa '), 'antrua');
    expect(normalizeTagName('ĐỒ UỐNG'), 'douong');
    expect(normalizeTagName('ca\u0300 phe\u0302'), 'caphe');
    expect(normalizeTagName('###'), '');
  });
  test('suggestions belong only to the selected category', () {
    final tags = [
      Record.create(Entity.tags, 'u', {'name': 'caphe', 'category_id': 'food'}),
      Record.create(Entity.tags, 'u', {
        'name': 'xangxe',
        'category_id': 'travel',
      }),
    ];
    expect(tagsForCategory(tags, 'food').map((t) => t.text('name')), ['caphe']);
    expect(tagsForCategory(tags, null), isEmpty);
  });
}
