import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/router.dart';
import 'package:finance_core/app/theme.dart';

void main() {
  group('PMV Navigation & Theme Specifications', () {
    test('NavigationBar defines exactly four primary tabs', () {
      expect(pmvTabs.length, equals(4));

      expect(pmvTabs[0].$1, equals('/'));
      expect(pmvTabs[0].$2, equals('Tổng quan'));

      expect(pmvTabs[1].$1, equals('/transactions'));
      expect(pmvTabs[1].$2, equals('Thu chi'));

      expect(pmvTabs[2].$1, equals('/transactions/pending'));
      expect(pmvTabs[2].$2, equals('Biến động'));

      expect(pmvTabs[3].$1, equals('/settings'));
      expect(pmvTabs[3].$2, equals('Cài đặt'));
    });

    test(
      'AppThemeColors defines semantic color palette for light and dark',
      () {
        final light = AppThemeColors.light;
        expect(light.income, isNotNull);
        expect(light.expense, isNotNull);
        expect(light.primaryAccent, isNotNull);

        final dark = AppThemeColors.dark;
        expect(dark.income, isNotNull);
        expect(dark.expense, isNotNull);
        expect(dark.primaryAccent, isNotNull);
      },
    );
  });
}
