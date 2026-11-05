import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finance_core/app/theme.dart';
import 'package:finance_core/features/calendar/calendar_screen.dart';
import 'package:finance_core/features/calendar/calendar_providers.dart';
import 'package:finance_core/features/calendar/calendar_models.dart';
import 'pmv_calendar_screen_test.dart' show FakeCalendar;

class DenseCalendar extends FakeCalendar {
  @override
  Future<List<CalendarEvent>> getEvents(
    List<int> ids,
    DateTime start,
    DateTime end,
  ) async => List.generate(
    6,
    (i) => CalendarEvent(
      id: i,
      title: 'Dense $i',
      start: DateTime(2024, 1, 2, 9 + i),
      end: DateTime(2024, 1, 2, 10 + i),
      allDay: false,
      calendarId: 1,
      color: 0xFFFFEB3B,
    ),
  );
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));
  for (final brightness in Brightness.values) {
    testWidgets(
      'dense calendar day and bright event chips remain readable in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = financeTheme(brightness);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              calendarRepositoryProvider.overrideWithValue(DenseCalendar()),
            ],
            child: MaterialApp(
              theme: theme,
              home: CalendarScreen(initialDate: DateTime(2024, 1, 2)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Color backgroundOf(Finder text, Color base) {
          final container = find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).color != null,
                ),
              )
              .evaluate()
              .map((e) => e.widget as Container)
              .first;
          return Color.alphaBlend(
            (container.decoration as BoxDecoration).color!,
            base,
          );
        }

        final day = find.text('2');
        final dayBg = backgroundOf(day, theme.scaffoldBackgroundColor);
        expect(
          contrast(tester.widget<Text>(day).style!.color!, dayBg),
          greaterThanOrEqualTo(4.5),
        );
        final chip = find.text('Dense 0').first;
        expect(
          contrast(
            tester.widget<Text>(chip).style!.color!,
            backgroundOf(chip, dayBg),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
