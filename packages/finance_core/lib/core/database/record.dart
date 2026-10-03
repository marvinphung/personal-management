import 'package:uuid/uuid.dart';

enum Entity {
  accounts,
  categories,
  tags,
  people,
  transactions,
  transactionTags,
  debts,
  debtPayments,
  notes,
  pendingBankEvents,
  bankBindings,
}

extension EntityTable on Entity {
  String get table => switch (this) {
    Entity.transactionTags => 'transaction_tags',
    Entity.debtPayments => 'debt_payments',
    Entity.pendingBankEvents => 'pending_bank_events',
    Entity.bankBindings => 'bank_bindings',
    _ => name,
  };
  static Entity parse(String table) =>
      Entity.values.firstWhere((e) => e.table == table);
}


enum TransactionType { income, expense, transfer }

enum TransactionPurpose { normal, debtDisbursement, debtRepayment }

enum DebtDirection { lent, borrowed }

/// Immutable data boundary. Monetary values must be integers, never doubles.
class Record {
  final Entity entity;
  final Map<String, dynamic> data;
  Record(this.entity, Map<String, dynamic> data)
    : data = Map.unmodifiable(data);
  String get id => text('id');
  String text(String key) => data[key]?.toString() ?? '';
  int money(String key) {
    final value = data[key];
    if (value == null) return 0;
    if (value is int) return value;
    // PostgreSQL numeric(20,0) arrives as an integer via JSON.
    if (value is! String || !RegExp(r'^-?\d+$').hasMatch(value)) {
      throw const FormatException('Invalid exact money value');
    }
    return int.parse(value);
  }

  bool flag(String key) => data[key] == true;
  bool get deleted => data['deleted_at'] != null;
  DateTime date(String key) => DateTime.parse(text(key)).toLocal();
  Record patch(Map<String, dynamic> values) =>
      Record(entity, {...data, ...values});
  Map<String, dynamic> get change => {'table': entity.table, 'data': data};
  factory Record.create(
    Entity entity,
    String user,
    Map<String, dynamic> values, {
    String? id,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return Record(entity, {
      'id': id ?? const Uuid().v4(),
      'user_id': user,
      'created_at': now,
      'updated_at': now,
      'client_modified_at': now,
      'mutation_id': const Uuid().v4(),
      'deleted_at': null,
      ...defaults(entity),
      ...values,
    });
  }
  static Map<String, dynamic> defaults(Entity e) => switch (e) {
    Entity.accounts => {
      'type': 'cash',
      'currency': 'VND',
      'opening_balance': 0,
      'icon': null,
      'is_archived': false,
    },
    Entity.categories => {
      'behavior': 'normal',
      'type': 'expense',
      'icon': null,
      'is_default': false,
      'is_archived': false,
    },
    Entity.tags => {},
    Entity.people => {'phone_optional': null, 'note': null},
    Entity.transactions => {
      'purpose': 'normal',
      'currency': 'VND',
      'account_id': null,
      'from_account_id': null,
      'to_account_id': null,
      'category_id': null,
      'description': '',
      'note': null,
    },
    Entity.transactionTags => {},
    Entity.debts => {
      'currency': 'VND',
      'due_at': null,
      'note': null,
      'status': 'active',
      'linked_transaction_id': null,
    },
    Entity.debtPayments => {'note': null, 'linked_transaction_id': null},
    Entity.notes => {
      'content': '',
      'is_pinned': false,
      'reminder_at': null,
      'person_id': null,
      'debt_id': null,
      'transaction_id': null,
    },
    Entity.pendingBankEvents => <String, dynamic>{},
    Entity.bankBindings => <String, dynamic>{},
  };
}
