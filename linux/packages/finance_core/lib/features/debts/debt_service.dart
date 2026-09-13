import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

class DebtService {
  final FinanceRepository repository;
  DebtService(this.repository);
  Future<void> createDebt({
    required Record person,
    required DebtDirection direction,
    required int amount,
    required String currency,
    Record? account,
    DateTime? due,
    String note = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final cash = account == null
        ? null
        : repository.create(Entity.transactions, {
            'type': direction == DebtDirection.lent ? 'expense' : 'income',
            'purpose': 'debt_disbursement',
            'amount': amount,
            'currency': currency,
            'account_id': account.id,
            'description':
                '${direction == DebtDirection.lent ? 'Lent to' : 'Borrowed from'} ${person.text('name')}',
            'occurred_at': now,
          });
    final debt = repository.create(Entity.debts, {
      'person_id': person.id,
      'direction': direction.name,
      'principal_amount': amount,
      'currency': currency,
      'started_at': now,
      'due_at': due?.toUtc().toIso8601String(),
      'note': note,
      'linked_transaction_id': cash?.id,
    });
    await repository.saveBatch([?cash, debt]);
  }

  Future<void> repay(
    Record debt,
    int amount, {
    Record? account,
    String note = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final cash = account == null
        ? null
        : repository.create(Entity.transactions, {
            'type': debt.text('direction') == 'lent' ? 'income' : 'expense',
            'purpose': 'debt_repayment',
            'amount': amount,
            'currency': debt.text('currency'),
            'account_id': account.id,
            'description': 'Debt repayment',
            'occurred_at': now,
          });
    final payment = repository.create(Entity.debtPayments, {
      'debt_id': debt.id,
      'amount': amount,
      'paid_at': now,
      'note': note,
      'linked_transaction_id': cash?.id,
    });
    await repository.saveBatch([?cash, payment]);
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
