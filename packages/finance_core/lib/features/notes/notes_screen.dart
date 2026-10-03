import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('Search notes'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v.toLowerCase()),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => showNoteForm(context),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Note')),
            ),
          ],
        ),
      ),
      Expanded(
        child: AsyncRecords(
          value: ref.watch(recordsProvider(Entity.notes)),
          builder: (rows) {
            final notes =
                rows
                    .where(
                      (r) => '${r.text('title')} ${r.text('content')}'
                          .toLowerCase()
                          .contains(query),
                    )
                    .toList()
                  ..sort((a, b) {
                    final pinned =
                        (b.flag('is_pinned') ? 1 : 0) -
                        (a.flag('is_pinned') ? 1 : 0);
                    return pinned != 0
                        ? pinned
                        : b.text('updated_at').compareTo(a.text('updated_at'));
                  });
            if (notes.isEmpty) {
              return EmptyState(
                title: context.tr('No notes yet'),
                description: context.tr(
                  'Keep repayment promises and payment reminders here.',
                ),
                onAdd: () => showNoteForm(context),
              );
            }
            return ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final n = notes[index];
                return ListTile(
                  leading: Icon(
                    n.flag('is_pinned') ? Icons.push_pin : Icons.notes,
                  ),
                  title: Text(n.text('title')),
                  subtitle: Text(
                    n.text('content'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => showNoteForm(context, record: n),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

Future<void> showNoteForm(BuildContext context, {Record? record}) =>
    showDialog<void>(
      context: context,
      builder: (_) => NoteForm(record: record),
    );

class NoteForm extends ConsumerStatefulWidget {
  final Record? record;
  const NoteForm({super.key, this.record});
  @override
  ConsumerState<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<NoteForm> {
  final title = TextEditingController(), content = TextEditingController();
  bool pinned = false, busy = false;
  String? error, person;
  DateTime? reminder;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    title.text = r?.text('title') ?? '';
    content.text = r?.text('content') ?? '';
    pinned = r?.flag('is_pinned') ?? false;
    person = r?.data['person_id'];
    if (r?.data['reminder_at'] != null) reminder = r!.date('reminder_at');
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await saveAndSync(ref, (repo) {
        final data = {
          'title': title.text.trim(),
          'content': content.text,
          'is_pinned': pinned,
          'reminder_at': reminder?.toUtc().toIso8601String(),
          'person_id': person,
        };
        return repo.save(
          widget.record?.patch(data) ?? repo.create(Entity.notes, data),
        );
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: widget.record == null
        ? context.tr('New note')
        : context.tr('Edit note'),
    busy: busy,
    error: error,
    save: save,
    children: [
      TextField(
        controller: title,
        autofocus: true,
        decoration: InputDecoration(labelText: context.tr('Title')),
      ),
      TextField(
        controller: content,
        minLines: 5,
        maxLines: 12,
        decoration: InputDecoration(labelText: context.tr('Note')),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Pinned')),
        value: pinned,
        onChanged: (v) => setState(() => pinned = v),
      ),
      RecordPicker(
        label: context.tr('Related person (optional)'),
        value: person,
        records: ref.watch(recordsProvider(Entity.people)).value ?? [],
        onChanged: (v) => setState(() => person = v),
        optional: true,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          reminder == null
              ? context.tr('Reminder date (optional)')
              : context.dateLabel(reminder!),
        ),
        subtitle: Text(
          context.tr('Date reference only; notifications are planned.'),
        ),
        trailing: reminder == null
            ? const Icon(Icons.calendar_today)
            : IconButton(
                onPressed: () => setState(() => reminder = null),
                icon: const Icon(Icons.clear),
              ),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: reminder ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => reminder = d);
        },
      ),
      if (widget.record != null)
        TextButton(
          onPressed: () async {
            if (await confirmDelete(context)) {
              await saveAndSync(ref, (r) => r.remove(widget.record!));
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Text(context.tr('Delete note')),
        ),
    ],
  );
}
