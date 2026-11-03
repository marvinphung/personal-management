import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'calendar_providers.dart';

/// Calendar selection sub-screen: lets the user choose which Google calendars
/// are shown in the calendar view.
class CalendarSettings extends ConsumerWidget {
  const CalendarSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calState = ref.watch(calendarProvider);

    if (!calState.hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cài đặt lịch')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cần quyền đọc lịch để hiển thị danh sách lịch.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(calendarProvider.notifier).requestPermission(),
                child: const Text('Yêu cầu quyền đọc lịch'),
              ),
            ],
          ),
        ),
      );
    }

    final calendars = calState.calendars;
    final selected = calState.selectedCalendarIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt lịch')),
      body: calendars.isEmpty
          ? const Center(child: Text('Không tìm thấy lịch nào.'))
          : ListView.builder(
              itemCount: calendars.length,
              itemBuilder: (context, i) {
                final cal = calendars[i];
                final isSelected = selected.contains(cal.id);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: Color(cal.color | 0xFF000000),
                  secondary: CircleAvatar(
                    backgroundColor: Color(cal.color | 0xFF000000),
                    radius: 10,
                  ),
                  title: Text(cal.name),
                  subtitle: Text(cal.accountName),
                  onChanged: (_) => ref
                      .read(calendarProvider.notifier)
                      .toggleCalendar(cal.id),
                );
              },
            ),
    );
  }
}
