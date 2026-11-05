import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/features/calendar/calendar_models.dart';

void main() {
  test(
    'exclusive all-day end does not add a phantom day; duplicates count once',
    () {
      final e = CalendarEvent(
        id: 1,
        title: 'Synthetic',
        start: DateTime.utc(2026, 11, 1),
        end: DateTime.utc(2026, 11, 2),
        allDay: true,
        calendarId: 1,
        color: 0,
      );
      final days = groupCalendarEvents(
        [e, e],
        DateTime(2026, 11, 1),
        DateTime(2026, 12),
      );
      expect(days.keys, [DateTime(2026, 11, 1)]);
      expect(days.values.single, hasLength(1));
    },
  );
  test(
    'timed event ending at midnight excludes the next day and clips long spans',
    () {
      final e = CalendarEvent(
        id: 1,
        title: 'Synthetic',
        start: DateTime(2025, 1),
        end: DateTime(2026, 11, 2),
        allDay: false,
        calendarId: 1,
        color: 0,
      );
      final days = groupCalendarEvents(
        [e],
        DateTime(2026, 11, 1),
        DateTime(2026, 12),
      );
      expect(days.keys, [DateTime(2026, 11, 1)]);
    },
  );
}
