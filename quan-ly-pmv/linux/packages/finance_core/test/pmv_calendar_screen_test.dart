import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/features/calendar/calendar_screen.dart';
import 'package:finance_core/features/calendar/calendar_repository.dart';
import 'package:finance_core/features/calendar/calendar_providers.dart';
import 'package:finance_core/features/calendar/calendar_models.dart';

class FakeCalendar extends CalendarRepository {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<CalendarInfo>> getCalendars() async => [];
  @override
  Future<List<int>> loadSelectedIds() async => [1];
  @override
  Future<List<CalendarEvent>> getEvents(
    List<int> ids,
    DateTime start,
    DateTime end,
  ) async => [
    CalendarEvent(
      id: 1,
      title: 'Synthetic last-day event',
      start: DateTime(2026, 11, 30, 9),
      end: DateTime(2026, 11, 30, 10),
      allDay: false,
      calendarId: 1,
      color: 0,
    ),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  testWidgets(
    'six-week month keeps its final day visible on an A54-sized screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeCalendar();
      Widget app(DateTime date) => ProviderScope(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: CalendarScreen(initialDate: date)),
      );
      await tester.pumpWidget(app(DateTime(2026, 11, 2)));
      await tester.pumpAndSettle();
      expect(find.text('30').hitTestable(), findsOneWidget);
      await tester.tap(find.text('30'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic last-day event'), findsWidgets);
      await tester.pumpWidget(app(DateTime(2026, 11, 4)));
      await tester.pumpAndSettle();
      expect(find.textContaining('4/11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
