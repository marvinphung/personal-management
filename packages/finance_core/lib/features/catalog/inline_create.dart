import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/providers.dart';
import '../../core/database/record.dart';
import '../../core/sync/outbox.dart';

Future<Record?> showInlineCreateCategory(
  BuildContext context,
  WidgetRef ref, {
  required String direction,
}) async {
  final nameController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(direction == 'income' ? 'Thêm danh mục thu' : 'Thêm danh mục chi'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            hintText: 'Ví dụ: Ăn ngoài, Tiết kiệm...',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() == true) {
              Navigator.pop(ctx, nameController.text.trim());
            }
          },
          child: const Text('Tạo'),
        ),
      ],
    ),
  );

  if (result == null || result.isEmpty) return null;

  final workspace = await ref.read(workspaceProvider.future);
  if (workspace == null) return null;

  final catId = const Uuid().v4();
  final newRecord = Record(Entity.categories, {
    'id': catId,
    'direction': direction,
    'name': result,
    'icon': 'category',
    'archived': false,
    'seed_rank': 999,
    'version': 1,
  });

  // Save to local SQLite
  await workspace.db.put(newRecord);

  // Enqueue outbox operation
  await workspace.sync.outbox.enqueue(
    OutboxOperation(
      type: 'create_category',
      payload: {
        'id': catId,
        'direction': direction,
        'name': result,
        'icon': 'category',
      },
    ),
  );

  return newRecord;
}

Future<Record?> showInlineCreateTag(
  BuildContext context,
  WidgetRef ref, {
  required String categoryId,
}) async {
  final nameController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Thêm thẻ mới'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên thẻ',
            hintText: 'Ví dụ: Cà phê, Xăng...',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên thẻ' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() == true) {
              Navigator.pop(ctx, nameController.text.trim());
            }
          },
          child: const Text('Tạo'),
        ),
      ],
    ),
  );

  if (result == null || result.isEmpty) return null;

  final workspace = await ref.read(workspaceProvider.future);
  if (workspace == null) return null;

  final tagId = const Uuid().v4();
  final newTag = Record(Entity.tags, {
    'id': tagId,
    'category_id': categoryId,
    'name': result,
    'archived': false,
    'version': 1,
  });

  await workspace.db.put(newTag);

  await workspace.sync.outbox.enqueue(
    OutboxOperation(
      type: 'create_tag',
      payload: {
        'id': tagId,
        'category_id': categoryId,
        'name': result,
      },
    ),
  );

  return newTag;
}
