import 'package:flutter/services.dart';
import 'money.dart';

/// Thousands grouping is presentation only; no floating-point conversion or
/// controller replacement, so editing, selection and IME composition stay intact.
class MoneyInputFormatter extends TextInputFormatter {
  final bool allowNegative;
  MoneyInputFormatter({this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var raw = newValue.text.replaceAll(',', '');
    if ((!allowNegative && raw.startsWith('-')) ||
        !RegExp(
          r'^-?\d*(?:\.\d*)?(?:[kKmM]|[tT](?:[rR]\d{0,6})?)?$',
        ).hasMatch(raw)) {
      return oldValue;
    }
    int offset(int at) => at < 0
        ? raw.length
        : newValue.text
              .substring(0, at.clamp(0, newValue.text.length))
              .replaceAll(',', '')
              .length;
    var base = offset(newValue.selection.baseOffset),
        extent = offset(newValue.selection.extentOffset);
    // Backspace immediately after an inserted comma deletes the preceding digit,
    // rather than repeatedly re-inserting the separator under the caret.
    final oldAt = oldValue.selection.baseOffset;
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldAt > 0 &&
        oldValue.text[oldAt - 1] == ',' &&
        oldValue.text.replaceRange(oldAt - 1, oldAt, '') == newValue.text) {
      final remove =
          oldValue.text.substring(0, oldAt - 1).replaceAll(',', '').length - 1;
      if (remove >= 0 &&
          remove < raw.length &&
          RegExp(r'\d').hasMatch(raw[remove])) {
        raw = raw.replaceRange(remove, remove + 1, '');
        base = (base - 1).clamp(0, raw.length);
        extent = (extent - 1).clamp(0, raw.length);
      }
    }
    final match = RegExp(r'^(-?)(\d*)(.*)$').firstMatch(raw)!;
    final formatted = '${match[1]}${Money.groupInteger(match[2]!)}${match[3]}';
    int caret(int logical) {
      if (logical <= 0) return 0;
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != ',') seen++;
        if (seen == logical) return i + 1;
      }
      return formatted.length;
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection(
        baseOffset: caret(base),
        extentOffset: caret(extent),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}
