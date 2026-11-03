import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/utils/money.dart';
import 'package:finance_core/core/utils/money_input_formatter.dart';

void main() {
  TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  test(
    'typing/pasting whole amounts inserts commas and preserves exact parsing',
    () {
      final formatter = MoneyInputFormatter();
      for (final text in ['1200000', '1,200,000', '1200000,']) {
        final result = formatter.formatEditUpdate(value(''), value(text));
        expect(result.text, '1,200,000');
        expect(Money.parse(result.text), 1200000);
      }
      expect(Money.parse('1,200,000'), 1200000);
      expect(Money.parse('1,234.50', currency: 'USD'), 123450);
      expect(Money.parseBalance('-1,234.50', currency: 'USD'), -123450);
      expect(() => Money.parse('1,20,000'), throwsFormatException);
    },
  );
  test('caret stays beside the edited digit and separators can be deleted', () {
    final f = MoneyInputFormatter();
    final mid = f.formatEditUpdate(value('12,345', 2), value('129,345', 3));
    expect(mid.text, '129,345');
    expect(mid.selection.baseOffset, 3);
    final deleted = f.formatEditUpdate(value('1,234', 2), value('1234', 1));
    expect(deleted.text, '234');
    expect(deleted.selection.baseOffset, 0);
    expect(f.formatEditUpdate(value('123'), value('')).text, '');
  });
  test(
    'decimal cents, shortcuts and signed opening balances remain usable',
    () {
      final f = MoneyInputFormatter();
      expect(f.formatEditUpdate(value(''), value('1234.50')).text, '1,234.50');
      expect(f.formatEditUpdate(value(''), value('1.2m')).text, '1.2m');
      expect(Money.parse('1tr2'), 1200000);
      expect(Money.parse('1tr'), 1000000);
      expect(
        MoneyInputFormatter(
          allowNegative: true,
        ).formatEditUpdate(value(''), value('-1234000')).text,
        '-1,234,000',
      );
      final composing = value(
        '1200000',
      ).copyWith(composing: const TextRange(start: 0, end: 7));
      expect(f.formatEditUpdate(value(''), composing), composing);
    },
  );
}
