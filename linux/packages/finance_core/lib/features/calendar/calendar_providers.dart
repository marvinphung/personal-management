import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'calendar_models.dart';
import 'calendar_repository.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (_) => CalendarRepository(),
);
final selectedMonthCalendarProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);

class CalendarNotifier extends StateNotifier<CalendarState> {
  static const _channel = MethodChannel('personal_finance/calendar');
  final CalendarRepository _repo;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _generation = 0;
  CalendarNotifier(this._repo) : super(const CalendarState()) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCalendarChanged') await requestPermission();
    });
  }
  Future<void> requestPermission() async {
    try {
      final granted = await _repo.requestPermission();
      if (!mounted) return;
      if (!granted) {
        state = const CalendarState(permissionDenied: true);
        return;
      }
      final calendars = await _repo.getCalendars();
      final ids = await _repo.loadSelectedIds();
      if (!mounted) return;
      state = CalendarState(
        hasPermission: true,
        calendars: calendars,
        selectedCalendarIds: ids,
        eventsByDay: state.eventsByDay,
      );
      await loadEventsForMonth(_month);
    } catch (_) {
      _fail();
    }
  }

  Future<void> toggleCalendar(int id) async {
    final ids = List<int>.from(state.selectedCalendarIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    try {
      await _repo.saveSelectedIds(ids);
      if (!mounted) return;
      state = CalendarState(
        hasPermission: state.hasPermission,
        calendars: state.calendars,
        selectedCalendarIds: ids,
      );
      await loadEventsForMonth(_month);
    } catch (_) {
      _fail();
    }
  }

  Future<void> loadEventsForMonth(DateTime month) async {
    _month = month;
    if (!state.hasPermission) return;
    final generation = ++_generation;
    final start = DateTime(
      month.year,
      month.month,
    ).subtract(const Duration(days: 7));
    final end = DateTime(
      month.year,
      month.month + 1,
    ).add(const Duration(days: 7));
    state = CalendarState(
      hasPermission: true,
      loading: true,
      calendars: state.calendars,
      selectedCalendarIds: state.selectedCalendarIds,
      eventsByDay: state.eventsByDay,
    );
    try {
      final events = await _repo.getEvents(
        state.selectedCalendarIds,
        start,
        end,
      );
      if (!mounted || generation != _generation) return;
      state = CalendarState(
        hasPermission: true,
        calendars: state.calendars,
        selectedCalendarIds: state.selectedCalendarIds,
        eventsByDay: groupCalendarEvents(events, start, end),
      );
    } catch (_) {
      if (generation == _generation) _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    state = CalendarState(
      hasPermission: state.hasPermission,
      calendars: state.calendars,
      selectedCalendarIds: state.selectedCalendarIds,
      eventsByDay: state.eventsByDay,
      error: 'Không thể cập nhật lịch. Kiểm tra quyền và thử lại.',
    );
  }

  @override
  void dispose() {
    ++_generation;
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>(
  (ref) => CalendarNotifier(ref.watch(calendarRepositoryProvider)),
);
