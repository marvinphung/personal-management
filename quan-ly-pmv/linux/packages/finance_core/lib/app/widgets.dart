import '../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AsyncRecords
// ─────────────────────────────────────────────────────────────────────────────

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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Could not load local data. Try reopening this screen.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String title, description;
  final VoidCallback? onAdd;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.onAdd,
    this.icon = Icons.inbox_outlined,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(context.tr('Thêm mới')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text(context.tr('Delete')),
      ),
    ],
  ),
).then((v) => v ?? false);

// ─────────────────────────────────────────────────────────────────────────────
// FormDialog — dialog form chuẩn cho mobile (full-screen style)
// ─────────────────────────────────────────────────────────────────────────────

class FormDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool busy;
  final bool saveEnabled;
  final String? error;
  final VoidCallback save;
  final List<Widget> appBarActions;
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.busy,
    required this.save,
    this.saveEnabled = true,
    this.error,
    this.appBarActions = const [],
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    // Trên mobile: dialog dạng bottom-sheet style với scroll
    // Trên wide: dialog chuẩn
    if (!isWide) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.tr('Cancel'),
              onPressed: busy ? null : () => Navigator.pop(context),
            ),
            actions: [
              ...appBarActions,
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: busy || !saveEnabled ? null : save,
                  child: Text(
                    busy ? context.tr('Saving…') : context.tr('Save'),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children) ...[
                  child,
                  const SizedBox(height: 14),
                ],
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: cs.onErrorContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    // Wide screen: AlertDialog chuẩn
    return AlertDialog(
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: cs.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// RecordPicker
// ─────────────────────────────────────────────────────────────────────────────

class RecordPicker extends StatelessWidget {
  final String label;
  final String? value;
  final List<Record> records;
  final ValueChanged<String?>? onChanged;
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
        DropdownMenuItem(value: '', child: Text(context.tr('Không chọn'))),
      for (final r in records)
        DropdownMenuItem(
          value: r.id,
          child: Text(r.text('name'), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged == null ? null : (v) => onChanged!(v == '' ? null : v),
  );
}
