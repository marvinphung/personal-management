import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/record.dart';
import 'inline_create.dart';

class TagChipPicker extends ConsumerWidget {
  final String categoryId;
  final List<Record> allTags;
  final Set<String> selectedTagIds;
  final ValueChanged<Set<String>> onChanged;

  const TagChipPicker({
    super.key,
    required this.categoryId,
    required this.allTags,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter tags belonging to this category
    final categoryTags = allTags
        .where((t) => t.text('category_id') == categoryId && !t.flag('archived'))
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final tag in categoryTags) ...[
          FilterChip(
            label: Text(tag.text('name')),
            selected: selectedTagIds.contains(tag.id),
            onSelected: (selected) {
              final newSet = Set<String>.from(selectedTagIds);
              if (selected) {
                newSet.add(tag.id);
              } else {
                newSet.remove(tag.id);
              }
              onChanged(newSet);
            },
          ),
        ],
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('Thêm thẻ'),
          onPressed: () async {
            final created = await showInlineCreateTag(context, ref, categoryId: categoryId);
            if (created != null) {
              final newSet = Set<String>.from(selectedTagIds)..add(created.id);
              onChanged(newSet);
            }
          },
        ),
      ],
    );
  }
}
