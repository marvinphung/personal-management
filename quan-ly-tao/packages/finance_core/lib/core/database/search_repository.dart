import 'dart:convert';
import 'package:drift/drift.dart' show Variable;
import 'local_database.dart';
import 'record.dart';

class SearchRepository {
  final LocalDatabase database;
  SearchRepository(this.database);
  Future<List<Record>> search(String query) async {
    final rows = await database.customSelect(
      """
SELECT DISTINCT r.entity,r.payload FROM records r
WHERE json_extract(r.payload,'\$.deleted_at') IS NULL AND (
 lower(COALESCE(json_extract(r.payload,'\$.description'),'')||' '||COALESCE(json_extract(r.payload,'\$.note'),'')||' '||COALESCE(json_extract(r.payload,'\$.name'),'')||' '||COALESCE(json_extract(r.payload,'\$.title'),'')||' '||COALESCE(json_extract(r.payload,'\$.content'),'')) LIKE ? ESCAPE '\\'
 OR (r.entity='transactions' AND EXISTS(SELECT 1 FROM records c WHERE c.entity='categories' AND c.id=json_extract(r.payload,'\$.category_id') AND lower(json_extract(c.payload,'\$.name')) LIKE ? ESCAPE '\\'))
 OR (r.entity='transactions' AND EXISTS(SELECT 1 FROM records l JOIN records t ON t.entity='tags' AND t.id=json_extract(l.payload,'\$.tag_id') WHERE l.entity='transaction_tags' AND json_extract(l.payload,'\$.deleted_at') IS NULL AND json_extract(l.payload,'\$.transaction_id')=r.id AND lower(json_extract(t.payload,'\$.name')) LIKE ? ESCAPE '\\'))
 OR (r.entity IN ('debts','notes') AND EXISTS(SELECT 1 FROM records p WHERE p.entity='people' AND p.id=json_extract(r.payload,'\$.person_id') AND lower(json_extract(p.payload,'\$.name')) LIKE ? ESCAPE '\\'))
 OR (r.entity='transactions' AND EXISTS(SELECT 1 FROM records d JOIN records p ON p.entity='people' AND p.id=json_extract(d.payload,'\$.person_id') WHERE d.entity='debts' AND (json_extract(d.payload,'\$.linked_transaction_id')=r.id OR EXISTS(SELECT 1 FROM records pay WHERE pay.entity='debt_payments' AND json_extract(pay.payload,'\$.debt_id')=d.id AND json_extract(pay.payload,'\$.linked_transaction_id')=r.id)) AND lower(json_extract(p.payload,'\$.name')) LIKE ? ESCAPE '\\'))
) AND r.entity NOT IN ('transaction_tags','debt_payments') ORDER BY r.entity,json_extract(r.payload,'\$.updated_at') DESC LIMIT 80
""",
      variables: List.generate(
        5,
        (_) => Variable(
          '%${query.toLowerCase().replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
        ),
      ),
    ).get();
    return rows
        .map(
          (r) => Record(
            EntityTable.parse(r.read<String>('entity')),
            jsonDecode(r.read<String>('payload')),
          ),
        )
        .toList();
  }
}
