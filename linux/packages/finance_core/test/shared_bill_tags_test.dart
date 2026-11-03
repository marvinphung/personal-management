import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/utils/tag_display.dart';

void main() {
  test(
    'category-scoped tags show a readable shared label without exposing internal slugs',
    () {
      final a = Record(Entity.tags, {
        'name': 'muachungabc',
        'display_name': 'Mua chung',
        'category_id': 'food',
      });
      final b = Record(Entity.tags, {
        'name': 'muachungdef',
        'display_name': 'Mua chung',
        'category_id': 'bills',
      });
      final share = Record(Entity.tags, {
        'name': 'sharebillabc',
        'display_name': 'Ăn uống',
      });
      expect(TagDisplay.forRecord(a), 'Mua chung');
      expect(TagDisplay.forRecord(b), 'Mua chung');
      expect(TagDisplay.forRecord(share), 'Ăn uống');
      expect(
        TagDisplay.forRecord(Record(Entity.tags, {'name': 'ansang'})),
        'Ăn sáng',
      );
    },
  );
}
