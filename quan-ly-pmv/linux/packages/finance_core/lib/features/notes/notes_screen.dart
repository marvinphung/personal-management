import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final people = ref.watch(recordsProvider(Entity.people)).value ?? [];

    return Column(
      children: [
        // ── Search & Add Row ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('Tìm kiếm ghi chú…'),
                    prefixIcon: Icon(Icons.search, color: colors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (v) => setState(() => query = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => showNoteForm(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Ghi chú'),
              ),
            ],
          ),
        ),

        // ── Note list ──────────────────────────────────────────────────────
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
                          : b
                                .text('updated_at')
                                .compareTo(a.text('updated_at'));
                    });
              if (notes.isEmpty) {
                return EmptyState(
                  title: 'Chưa có ghi chú nào',
                  description:
                      'Lưu lại các lời hứa trả nợ, cam kết hoặc nhắc nhở tại đây.',
                  icon: Icons.notes_rounded,
                  onAdd: () => showNoteForm(context),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final n = notes[index];
                  final isPinned = n.flag('is_pinned');
                  final personId = n.data['person_id'] as String?;
                  final personName = people
                      .where((p) => p.id == personId)
                      .firstOrNull
                      ?.text('name');
                  final hasReminder = n.data['reminder_at'] != null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => showNoteForm(context, record: n),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isPinned) ...[
                                  Icon(
                                    Icons.push_pin,
                                    size: 16,
                                    color: colors.primaryAccent,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    n.text('title').isEmpty
                                        ? 'Ghi chú không tiêu đề'
                                        : n.text('title'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (n.text('content').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                n.text('content'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (personName != null || hasReminder) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (personName != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.bgElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 12,
                                            color: colors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            personName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (hasReminder) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.warning.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.alarm_outlined,
                                            size: 12,
                                            color: colors.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.dateLabel(
                                              n.date('reminder_at'),
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NoteForm
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    final colors = context.colors;
    final people = ref.watch(recordsProvider(Entity.people)).value ?? [];

    return FormDialog(
      title: widget.record == null ? 'Ghi chú mới' : 'Chỉnh sửa ghi chú',
      busy: busy,
      error: error,
      save: save,
      children: [
        TextField(
          controller: title,
          autofocus: widget.record == null,
          decoration: InputDecoration(
            labelText: context.tr('Title'),
            hintText: 'Nhập tiêu đề…',
            prefixIcon: Icon(Icons.title_rounded),
          ),
          textInputAction: TextInputAction.next,
        ),
        TextField(
          controller: content,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: context.tr('Note'),
            hintText: 'Nhập nội dung ghi chú…',
            alignLabelWithHint: true,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Row(
                children: [
                  Icon(
                    Icons.push_pin_outlined,
                    size: 18,
                    color: pinned ? colors.primaryAccent : colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ghim lên đầu',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              value: pinned,
              onChanged: (v) => setState(() => pinned = v),
            ),
          ),
        ),
        RecordPicker(
          label: 'Người liên quan (tuỳ chọn)',
          value: person,
          records: people,
          onChanged: (v) => setState(() => person = v),
          optional: true,
        ),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: reminder ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => reminder = d);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alarm_outlined,
                  size: 18,
                  color: colors.primaryAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày nhắc nhở (tuỳ chọn)',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        reminder == null
                            ? 'Không có nhắc nhở'
                            : context.dateLabel(reminder!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: reminder == null
                              ? colors.textMuted
                              : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reminder != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => reminder = null),
                    tooltip: 'Xoá nhắc nhở',
                  )
                else
                  Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
              ],
            ),
          ),
        ),
        if (widget.record != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                if (await confirmDelete(context)) {
                  await saveAndSync(ref, (r) => r.remove(widget.record!));
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: Icon(Icons.delete_outline, size: 18, color: colors.expense),
              label: Text(
                'Xoá ghi chú này',
                style: TextStyle(color: colors.expense),
              ),
            ),
          ),
      ],
    );
  }
}
