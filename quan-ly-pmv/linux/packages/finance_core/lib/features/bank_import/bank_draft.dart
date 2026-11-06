import 'package:uuid/uuid.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

/// Android-local suggestion. Never pass this map to the finance sync queue.
class BankDraft {
  final String id, owner, fingerprint, bankCode, currency, direction;
  final int amountMinor, currencyScale;
  final DateTime occurredAt;
  final String description, occurredAtSource;
  BankDraft.fromMap(Map<String, dynamic> map)
    : id = map['id'] as String,
      owner = map['owner'] as String,
      fingerprint = map['fingerprint'] as String,
      bankCode = map['bankCode'] as String,
      currency = map['currency'] as String,
      currencyScale = map['currencyScale'] as int,
      direction = map['direction'] as String,
      amountMinor = map['amountMinor'] as int,
      occurredAt = DateTime.fromMillisecondsSinceEpoch(
        map['occurredAtMillis'] as int,
      ),
      description = map['descriptionCandidate'] as String? ?? '',
      occurredAtSource = map['occurredAtSource'] as String;

  String get bankName => switch (bankCode) {
    'mbbank' => 'MB Bank',
    'vietinbank' => 'VietinBank iPay',
    'bidv' => 'BIDV',
    'techcombank' => 'Techcombank',
    _ => bankCode,
  };
  String get transactionId =>
      const Uuid().v5(Namespace.url.value, 'finance:bank:$owner:$fingerprint');
  static const usdVndRate = 27000;
  String get classificationCurrency => currency == 'USD' ? 'VND' : currency;
  int get classificationAmount =>
      currency == 'USD' ? amountMinor * 270 : amountMinor;

  Record toTransaction(
    FinanceRepository repository, {
    String? accountId,
    String? targetCurrency,
  }) {
    final target = targetCurrency ?? currency;
    if (target != currency && !(currency == 'USD' && target == 'VND')) {
      throw const FormatException('Unsupported currency conversion');
    }
    final converted = target != currency;
    return repository.create(Entity.transactions, {
      'amount': converted ? classificationAmount : amountMinor,
      'currency': target,
      'type': direction,
      'description': description,
      'bank_source': {
        'bank': bankCode,
        'timeSource': occurredAtSource,
        if (converted) ...{
          'original_amount': amountMinor,
          'original_currency': currency,
          'exchange_rate': usdVndRate,
        },
      },
      'account_id': accountId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
    }, id: transactionId);
  }
}
