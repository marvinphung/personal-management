// Calendar data models - read-only
class CalendarInfo {
  final int id;
  final String name;
  final String accountName;
  final String accountType;
  final int color;
  final bool visible;

  CalendarInfo({
    required this.id,
    required this.name,
    required this.accountName,
    required this.accountType,
    required this.color,
    required this.visible,
  });
}

class CalendarEvent {
  final int id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final int calendarId;
  final int color;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarId,
    required this.color,
  });

  bool get isMultiDay => end.difference(start).inDays >= 1;
}

class CalendarState {
  final bool loading;
  final String? error;
  final bool hasPermission;
  final bool permissionDenied;
  final List<CalendarInfo> calendars;
  final List<int> selectedCalendarIds;
  final Map<DateTime, List<CalendarEvent>> eventsByDay; // day only (no time)

  const CalendarState({
    this.loading = false,
    this.error,
    this.hasPermission = false,
    this.permissionDenied = false,
    this.calendars = const [],
    this.selectedCalendarIds = const [],
    this.eventsByDay = const {},
  });
}

/// Clip to the requested window; end is exclusive for both all-day and timed events.
Map<DateTime, List<CalendarEvent>> groupCalendarEvents(
  Iterable<CalendarEvent> events,
  DateTime start,
  DateTime end,
) {
  final result = <DateTime, List<CalendarEvent>>{};
  for (final e in events) {
    final a = e.allDay ? e.start.toUtc() : e.start.toLocal();
    final b = e.allDay ? e.end.toUtc() : e.end.toLocal();
    var day = DateTime(a.year, a.month, a.day);
    final last = DateTime(b.year, b.month, b.day);
    if (day.isBefore(start)) day = start;
    while (day.isBefore(end) && !day.isAfter(last)) {
      final atEndMidnight =
          day == last &&
          b.hour == 0 &&
          b.minute == 0 &&
          b.second == 0 &&
          b.millisecond == 0 &&
          b.microsecond == 0;
      if (!atEndMidnight || !b.isAfter(a)) {
        final values = result[day] ??= [];
        if (!values.any(
          (other) => other.id == e.id && other.start == e.start,
        )) {
          values.add(e);
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }
  return result;
}
