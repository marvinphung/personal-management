import 'package:flutter/services.dart';
import 'calendar_models.dart';

/// Flutter-side calendar repository using MethodChannel [personal_finance/calendar].
/// Only reads from the minhvu2592005@gmail.com / com.google account.
class CalendarRepository {
  static const _channel = MethodChannel('personal_finance/calendar');

  /// Requests READ_CALENDAR permission on the host platform.
  /// Returns true if permission is granted.
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  /// Fetches all calendars belonging to minhvu2592005@gmail.com / com.google.
  Future<List<CalendarInfo>> getCalendars() async {
    final raw = await _channel.invokeMethod<List>('getCalendars');
    if (raw == null) return [];
    return raw.cast<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);
      return CalendarInfo(
        id: (map['id'] as num).toInt(),
        name: map['name'] as String? ?? '',
        accountName: map['account_name'] as String? ?? '',
        accountType: map['account_type'] as String? ?? '',
        color: (map['color'] as num? ?? 0).toInt(),
        visible: map['visible'] as bool? ?? true,
      );
    }).toList();
  }

  /// Fetches calendar instances (handles recurrence) for the given calendar IDs
  /// in the half-open interval [start, end).
  Future<List<CalendarEvent>> getEvents(
    List<int> calendarIds,
    DateTime start,
    DateTime end,
  ) async {
    if (calendarIds.isEmpty) return [];
    final raw = await _channel.invokeMethod<List>('getInstances', {
      'calendarIds': calendarIds,
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    });
    if (raw == null) return [];
    return raw.cast<Map>().map((m) {
      final map = Map<String, dynamic>.from(m);
      return CalendarEvent(
        id: (map['id'] as num).toInt(),
        title: map['title'] as String? ?? '',
        start: DateTime.fromMillisecondsSinceEpoch(
          (map['dtStart'] as num).toInt(),
          isUtc: map['allDay'] == true,
        ),
        end: DateTime.fromMillisecondsSinceEpoch(
          (map['dtEnd'] as num).toInt(),
          isUtc: map['allDay'] == true,
        ),
        allDay: map['allDay'] as bool? ?? false,
        calendarId: (map['calId'] as num).toInt(),
        color: (map['color'] as num? ?? 0).toInt(),
      );
    }).toList();
  }

  Future<List<int>> loadSelectedIds() async =>
      (await _channel.invokeListMethod<int>('loadSelectedIds')) ?? [];
  Future<void> saveSelectedIds(List<int> ids) =>
      _channel.invokeMethod<void>('saveSelectedIds', {'ids': ids});
}
