import 'package:uuid/uuid.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

class DebtService {
  final FinanceRepository repository;
  DebtService(this.repository);

  /// Saves a debt disbursement transaction (Cho vay or Vay nợ) and its linked debt
  /// atomically in ONE batch in SQLite/outbox.
  Future<void> saveDisbursementTransaction(
    Record transaction,
    Record person,
    DebtDirection direction,
    List<Record> tags, {
    String? importKey,
  }) async {
    final expectedType = direction == DebtDirection.lent ? 'expense' : 'income';
    if (transaction.text('type') != expectedType) {
      throw FormatException(
        'Disbursement ${direction.name} requires transaction type $expectedType',
      );
    }

    final debtId = const Uuid().v5(
      Namespace.url.value,
      'finance:lending:${transaction.id}',
    );

    final debt = repository.create(Entity.debts, {
      'person_id': person.id,
      'direction': direction.name,
      'principal_amount': transaction.money('amount'),
      'currency': transaction.text('currency'),
      'started_at': transaction.text('occurred_at'),
      'note': transaction.text('note'),
      'status': 'active',
      'linked_transaction_id': transaction.id,
      'exclude_from_totals': false,
    }, id: debtId);

    await repository.saveTransaction(
      transaction.patch({
        'purpose': 'debt_disbursement',
        'exclude_from_totals': false,
      }),
      tags,
      relatedRecords: [debt],
      importKey: importKey,
    );
  }

  /// Saves a debt repayment transaction (Thu nợ or Trả nợ) and its linked debt_payment
  /// atomically in ONE batch in SQLite/outbox.
  /// Overpayment is allowed (no check against remaining balance).
  Future<void> saveRepaymentTransaction(
    Record transaction,
    Record debt,
    List<Record> tags, {
    String? importKey,
  }) async {
    debt = await repository.db.get(Entity.debts, debt.id) ?? debt;
    if (debt.text('status') == 'completed' ||
        debt.text('status') == 'cancelled') {
      throw const FormatException('Khoản công nợ đã hoàn tất');
    }
    if (transaction.text('currency') != debt.text('currency')) {
      throw const FormatException('Tiền tệ phải khớp khoản công nợ');
    }
    final expectedType = debt.text('direction') == 'lent'
        ? 'income'
        : 'expense';
    if (transaction.text('type') != expectedType) {
      throw FormatException(
        'Repayment for debt direction ${debt.text('direction')} requires transaction type $expectedType',
      );
    }

    final paymentId = const Uuid().v5(
      Namespace.url.value,
      'finance:payment:${transaction.id}',
    );

    final payment = repository.create(Entity.debtPayments, {
      'debt_id': debt.id,
      'amount': transaction.money('amount'),
      'paid_at': transaction.text('occurred_at'),
      'note': transaction.text('note'),
      'linked_transaction_id': transaction.id,
    }, id: paymentId);

    await repository.saveTransaction(
      transaction.patch({
        'purpose': 'debt_repayment',
        'exclude_from_totals': false,
      }),
      tags,
      relatedRecords: [payment],
      importKey: importKey,
    );
  }

  /// Manually marks a debt as completed without creating any balancing transaction
  /// or mutating original amounts or payment history.
  Future<void> markDebtCompleted(Record debt) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = debt.patch({
      'status': 'completed',
      'manual_completed_at': now,
    });
    await repository.saveBatch([updated]);
  }

  /// Legacy helper for lending transactions (kept for backward compatibility).
  Future<void> saveLendingTransaction(
    Record transaction,
    Record person,
    List<Record> tags, {
    String? importKey,
  }) async {
    await saveDisbursementTransaction(
      transaction,
      person,
      DebtDirection.lent,
      tags,
      importKey: importKey,
    );
  }

  Future<void> createDebt({
    required Record person,
    required DebtDirection direction,
    required int amount,
    required String currency,
    Record? account,
    DateTime? due,
    DateTime? startedAt,
    String note = '',
  }) async {
    final now = (startedAt ?? DateTime.now()).toUtc().toIso8601String();
    final lendingCategory = (await repository.db.list(Entity.categories))
        .where(
          (c) =>
              !c.flag('is_archived') &&
              (direction == DebtDirection.lent
                  ? (c.text('behavior') == 'cong_no_expense' ||
                        c.text('behavior') == 'lending')
                  : c.text('behavior') == 'cong_no_income'),
        )
        .firstOrNull;

    final cash = repository.create(Entity.transactions, {
      'type': direction == DebtDirection.lent ? 'expense' : 'income',
      'purpose': 'debt_disbursement',
      'exclude_from_totals': false,
      'category_id': lendingCategory?.id,
      'amount': amount,
      'currency': currency,
      'account_id': account?.id,
      'description':
          '${direction == DebtDirection.lent ? 'Cho vay' : 'Vay nợ'} ${person.text('name')}',
      'occurred_at': now,
    });

    final debt = repository.create(Entity.debts, {
      'person_id': person.id,
      'direction': direction.name,
      'principal_amount': amount,
      'currency': currency,
      'started_at': now,
      'due_at': due?.toUtc().toIso8601String(),
      'exclude_from_totals': false,
      'note': note,
      'status': 'active',
      'linked_transaction_id': cash.id,
    });
    final action = direction == DebtDirection.lent ? 'chovay' : 'vayno';
    final tags = (await repository.db.list(Entity.tags))
        .where(
          (t) =>
              t.text('category_id') == lendingCategory?.id &&
              t.text('name') == action,
        )
        .toList();
    await repository.saveTransaction(cash, tags, relatedRecords: [debt]);
  }

  Future<void> repay(
    Record debt,
    int amount, {
    Record? account,
    DateTime? paidAt,
    String note = '',
  }) async {
    final type = debt.text('direction') == 'lent' ? 'income' : 'expense';
    final category = (await repository.db.list(Entity.categories))
        .where(
          (c) =>
              !c.flag('is_archived') &&
              c.text('behavior') ==
                  (type == 'income' ? 'cong_no_income' : 'cong_no_expense'),
        )
        .firstOrNull;
    final action = type == 'income' ? 'thuno' : 'tranno';
    final tags = (await repository.db.list(Entity.tags))
        .where(
          (t) =>
              t.text('category_id') == category?.id && t.text('name') == action,
        )
        .toList();
    final transaction = repository.create(Entity.transactions, {
      'type': type,
      'category_id': category?.id,
      'amount': amount,
      'currency': debt.text('currency'),
      'account_id': account?.id,
      'description': type == 'income' ? 'Thu nợ' : 'Trả nợ',
      'note': note,
      'occurred_at': (paidAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
    await saveRepaymentTransaction(transaction, debt, tags);
  }

  Future<void> updateDebt(
    Record debt, {
    required Record person,
    required DebtDirection direction,
    required int amount,
    DateTime? startedAt,
    Record? account,
    DateTime? due,
    String note = '',
  }) async {
    final current = await repository.db.get(Entity.debts, debt.id);
    if (current == null || current.deleted) {
      throw const FormatException('Không tìm thấy khoản công nợ');
    }
    final original = await repository.db.get(
      Entity.transactions,
      current.text('linked_transaction_id'),
    );
    final bankReadOnly = original?.data['bank_source'] != null;
    if (bankReadOnly &&
        (amount != current.money('principal_amount') ||
            direction.name != current.text('direction') ||
            account?.id != original?.data['account_id'] ||
            (startedAt != null &&
                !startedAt.isAtSameMomentAs(original!.date('occurred_at'))))) {
      throw const FormatException('Thông tin giao dịch ngân hàng chỉ được đọc');
    }
    final payments = (await repository.db.list(
      Entity.debtPayments,
    )).where((p) => p.text('debt_id') == debt.id);
    if (direction.name != current.text('direction') && payments.isNotEmpty) {
      throw const FormatException(
        'Không thể đổi loại công nợ đã có lần thu/trả',
      );
    }
    final category = (await repository.db.list(Entity.categories))
        .where(
          (c) =>
              !c.flag('is_archived') &&
              c.text('behavior') ==
                  (direction == DebtDirection.lent
                      ? 'cong_no_expense'
                      : 'cong_no_income'),
        )
        .firstOrNull;
    final updated = current.patch({
      'person_id': person.id,
      'direction': direction.name,
      'principal_amount': amount,
      if (startedAt != null) 'started_at': startedAt.toUtc().toIso8601String(),
      'note': note,
      'due_at': due?.toUtc().toIso8601String(),
      'exclude_from_totals': false,
    });
    final rows = <Record>[updated];
    if (original != null) {
      rows.add(
        original.patch({
          'amount': amount,
          if (startedAt != null && !bankReadOnly)
            'occurred_at': startedAt.toUtc().toIso8601String(),
          'type': direction == DebtDirection.lent ? 'expense' : 'income',
          'account_id': account?.id,
          'category_id': category?.id ?? original.data['category_id'],
          'note': note,
          if (!bankReadOnly)
            'description':
                '${direction == DebtDirection.lent ? 'Cho vay' : 'Vay nợ'} ${person.text('name')}',
          'exclude_from_totals': false,
        }),
      );
      if (direction.name != current.text('direction')) {
        final oldLinks = (await repository.db.list(
          Entity.transactionTags,
        )).where((l) => l.text('transaction_id') == original.id);
        final now = DateTime.now().toUtc().toIso8601String();
        rows.addAll(oldLinks.map((l) => l.patch({'deleted_at': now})));
        final tag = (await repository.db.list(Entity.tags))
            .where(
              (t) =>
                  t.text('category_id') == category?.id &&
                  t.text('name') ==
                      (direction == DebtDirection.lent ? 'chovay' : 'vayno'),
            )
            .firstOrNull;
        if (tag != null) {
          final id = const Uuid().v5(
            Namespace.url.value,
            'finance:${original.id}:${tag.id}',
          );
          final existing = await repository.db.get(Entity.transactionTags, id);
          rows.add(
            (existing ??
                    repository.create(Entity.transactionTags, {
                      'transaction_id': original.id,
                      'tag_id': tag.id,
                    }, id: id))
                .patch({'deleted_at': null}),
          );
        }
      }
    }
    for (final payment in payments) {
      final movement = await repository.db.get(
        Entity.transactions,
        payment.text('linked_transaction_id'),
      );
      if (movement != null) {
        rows.add(movement.patch({'exclude_from_totals': false}));
      }
    }
    await repository.saveBatch(rows);
  }

  Future<void> removePayment(Record payment) async {
    final deleted = DateTime.now().toUtc().toIso8601String();
    final cash = await repository.db.get(
      Entity.transactions,
      payment.text('linked_transaction_id'),
    );
    await repository.saveBatch([
      payment.patch({'deleted_at': deleted}),
      if (cash != null) cash.patch({'deleted_at': deleted}),
    ]);
  }
}
