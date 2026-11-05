import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import 'calendar_providers.dart';

/// Calendar selection sub-screen: lets the user choose which Google calendars
/// are shown in the calendar view.
class CalendarSettings extends ConsumerWidget {
  const CalendarSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calState = ref.watch(calendarProvider);
    final colors = context.colors;

    if (!calState.hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cài đặt lịch')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 48,
                  color: colors.primaryAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cần quyền đọc lịch để hiển thị danh sách lịch Google.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(calendarProvider.notifier).requestPermission(),
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: const Text('Yêu cầu quyền đọc lịch'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final calendars = calState.calendars;
    final selected = calState.selectedCalendarIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt lịch')),
      body: calendars.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: colors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không tìm thấy lịch nào trên thiết bị.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Text(
                  'Chọn các lịch hiển thị trong ứng dụng và widget màn hình chính:',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      for (int i = 0; i < calendars.length; i++) ...[
                        _CalendarTile(
                          calendar: calendars[i],
                          isSelected: selected.contains(calendars[i].id),
                          onChanged: (_) => ref
                              .read(calendarProvider.notifier)
                              .toggleCalendar(calendars[i].id),
                        ),
                        if (i < calendars.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 52,
                            color: colors.borderSubtle,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  final dynamic calendar;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _CalendarTile({
    required this.calendar,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final calColor = Color((calendar.color as int) | 0xFF000000);

    return CheckboxListTile(
      value: isSelected,
      activeColor: colors.primaryAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      secondary: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: calColor, shape: BoxShape.circle),
      ),
      title: Text(
        calendar.name as String,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        calendar.accountName as String,
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
      ),
      onChanged: onChanged,
    );
  }
}
