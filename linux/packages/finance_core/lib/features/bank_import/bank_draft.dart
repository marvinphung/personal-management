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
    _ => bankCode,
  };
  String get transactionId =>
      const Uuid().v5(Namespace.url.value, 'finance:bank:$owner:$fingerprint');
  Record toTransaction(FinanceRepository repository, {String? accountId}) =>
      repository.create(Entity.transactions, {
        'amount': amountMinor,
        'currency': currency,
        'type': direction,
        'description': '',
        'account_id': accountId,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      }, id: transactionId);
}
