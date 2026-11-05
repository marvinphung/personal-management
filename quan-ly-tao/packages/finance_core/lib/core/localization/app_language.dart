import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'translations.dart';

/// Presentation-only localization. Never pass translated labels into persistence.
extension FinanceLanguage on BuildContext {
  String get languageCode => Localizations.localeOf(this).languageCode;

  String tr(String english, [Map<String, Object> arguments = const {}]) {
    var text = languageCode == 'vi'
        ? vietnamese[english] ?? english
        : switch (english) {
            'e_wallet' => 'e wallet',
            'debt_disbursement' => 'debt disbursement',
            'debt_repayment' => 'debt repayment',
            'partially_paid' => 'partially paid',
            _ => english,
          };
    for (final entry in arguments.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return text;
  }

  String dateLabel(DateTime date, {bool time = false}) {
    final format = DateFormat.yMMMd(languageCode);
    if (time) format.add_Hm();
    return format.format(date.toLocal());
  }
}
