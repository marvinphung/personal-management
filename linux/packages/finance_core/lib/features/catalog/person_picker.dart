import 'package:flutter/material.dart';
import '../../core/database/record.dart';
import 'catalog_screen.dart';

/// Always offers inline creation, including an empty catalog after a reset.
class PersonPicker extends StatefulWidget {
  final String label;
  final String? value;
  final List<Record> records;
  final ValueChanged<String?> onChanged;
  const PersonPicker({
    super.key,
    required this.label,
    required this.value,
    required this.records,
    required this.onChanged,
  });
  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  int revision = 0;
  static const createId = '__create_person__';
  Future<void> select(String? id) async {
    if (id != createId) {
      widget.onChanged(id);
      return;
    }
    final created = await showCatalogForm(context, Entity.people);
    if (!mounted) return;
    if (created != null) widget.onChanged(created.id);
    setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey('${widget.value}-${widget.records.length}-$revision'),
    initialValue: widget.records.any((p) => p.id == widget.value)
        ? widget.value
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: 'Chọn hoặc thêm người',
    ),
    items: [
      for (final p in widget.records)
        DropdownMenuItem(
          value: p.id,
          child: Text(p.text('name'), overflow: TextOverflow.ellipsis),
        ),
      const DropdownMenuItem(value: createId, child: Text('＋ Thêm người mới')),
    ],
    onChanged: select,
  );
}
