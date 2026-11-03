import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/features/calendar/calendar_models.dart';

void main() {
  group('PMV Calendar Specifications', () {
    test('CalendarEvent model properties', () {
      final now = DateTime.now();
      final timedEvent = CalendarEvent(
        id: 1,
        title: 'Họp dự án PMV',
        start: now,
        end: now.add(const Duration(hours: 1)),
        allDay: false,
        calendarId: 10,
        color: 0xFF2DD4BF,
      );

      expect(timedEvent.title, equals('Họp dự án PMV'));
      expect(timedEvent.allDay, isFalse);
      expect(timedEvent.isMultiDay, isFalse);

      final multiDayEvent = CalendarEvent(
        id: 2,
        title: 'Nghỉ lễ',
        start: now,
        end: now.add(const Duration(days: 3)),
        allDay: true,
        calendarId: 10,
        color: 0xFFF87171,
      );

      expect(multiDayEvent.allDay, isTrue);
      expect(multiDayEvent.isMultiDay, isTrue);
    });

    test('CalendarInfo handles com.google account filtering', () {
      final cal = CalendarInfo(
        id: 1,
        name: 'Personal',
        accountName: 'minhvu2592005@gmail.com',
        accountType: 'com.google',
        color: 0xFF2DD4BF,
        visible: true,
      );

      expect(cal.accountName, equals('minhvu2592005@gmail.com'));
      expect(cal.accountType, equals('com.google'));
      expect(cal.visible, isTrue);
    });
  });
}
