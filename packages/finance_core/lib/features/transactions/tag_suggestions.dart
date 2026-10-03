import '../../core/database/record.dart';

List<Record> tagSuggestions(List<Record> tags, List<Record> links) {
  final lastUsed = <String, int>{};
  for (final link in links.where((r) => !r.deleted)) {
    final id = link.text('tag_id'),
        time = link.date('updated_at').microsecondsSinceEpoch;
    if (time > (lastUsed[id] ?? 0)) lastUsed[id] = time;
  }
  return tags.where((t) => !t.deleted).toList()..sort((a, b) {
    final recent = (lastUsed[b.id] ?? 0).compareTo(lastUsed[a.id] ?? 0);
    return recent != 0 ? recent : a.text('name').compareTo(b.text('name'));
  });
}

List<Record> tagsForCategory(List<Record> tags, String? category) =>
    category == null
    ? []
    : tags
          .where((t) => !t.deleted && t.text('category_id') == category)
          .toList();
