import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/utils/money.dart';

void main() {
  test('opening balances allow exact zero and negative values', () {
    expect(Money.parseBalance('0.00', currency: 'USD'), 0);
    expect(Money.parseBalance('-1.23', currency: 'USD'), -123);
    expect(() => Money.parseBalance('1-2'), throwsFormatException);
    expect(() => Money.parse('0'), throwsFormatException);
  });

  for (final pair in {
    '45k': 45000,
    '120k': 120000,
    '1m': 1000000,
    '1.5m': 1500000,
    '1.2m': 1200000,
    '45K': 45000,
    '45000': 45000,
  }.entries) {
    test(
      'parses ${pair.key} exactly',
      () => expect(Money.parse(pair.key), pair.value),
    );
  }
  test(
    'rejects fractional VND',
    () => expect(() => Money.parse('1.1'), throwsFormatException),
  );
  test(
    'parses cents without binary floating point',
    () => expect(Money.parse('1.23', currency: 'USD'), 123),
  );
  test('rejects negative and excessive amounts', () {
    expect(() => Money.parse('-1'), throwsFormatException);
    expect(
      () => Money.parse('999999999999999999999999'),
      throwsFormatException,
    );
  });
}
