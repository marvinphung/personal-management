import '../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/record.dart';

class AsyncRecords extends StatelessWidget {
  final AsyncValue<List<Record>> value;
  final Widget Function(List<Record>) builder;
  const AsyncRecords({super.key, required this.value, required this.builder});
  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: false,
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => Center(
      child: Text(
        context.tr('Could not load local data. Try reopening this screen.'),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, description;
  final VoidCallback? onAdd;
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.onAdd,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 42),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          if (onAdd != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add your first record')),
            ),
          ],
        ],
      ),
    ),
  );
}

String userError(BuildContext context, Object error) => error is FormatException
    ? context.tr(error.message)
    : context.tr(
        'Could not save this change. Please check the fields and try again.',
      );
void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirmDelete(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.tr('Delete this record?')),
    content: Text(
      context.tr(
        'It will be removed from your lists and synchronized to your other devices.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(context.tr('Delete')),
      ),
    ],
  ),
).then((v) => v ?? false);

class FormDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool busy;
  final bool saveEnabled;
  final String? error;
  final VoidCallback save;
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.busy,
    required this.save,
    this.saveEnabled = true,
    this.error,
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(height: 16),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: busy || !saveEnabled ? null : save,
        child: Text(busy ? context.tr('Saving…') : context.tr('Save')),
      ),
    ],
  );
}

class RecordPicker extends StatelessWidget {
  final String label;
  final String? value;
  final List<Record> records;
  final ValueChanged<String?> onChanged;
  final bool optional;
  const RecordPicker({
    super.key,
    required this.label,
    required this.value,
    required this.records,
    required this.onChanged,
    this.optional = false,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: records.any((r) => r.id == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      if (optional)
        DropdownMenuItem(value: '', child: Text(context.tr('None'))),
      for (final r in records)
        DropdownMenuItem(
          value: r.id,
          child: Text(r.text('name'), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => onChanged(v == '' ? null : v),
  );
}
