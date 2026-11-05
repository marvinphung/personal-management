import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';
import '../debts/debt_service.dart';
import 'bank_draft.dart';

class BankConfirmation {
  static Future<void> save(
    FinanceRepository repository,
    BankDraft draft,
    Record transaction,
    List<Record> tags, {
    Record? borrower,
    Record? person,
    DebtDirection? disbursementDirection,
    Record? linkedDebt,
  }) async {
    if (repository.userId != draft.owner ||
        transaction.id != draft.transactionId) {
      throw const FormatException('Please sign in again');
    }

    final importKey = 'bank:${draft.fingerprint}';

    // 1. Repayment of an existing debt (Thu nợ or Trả nợ)
    if (linkedDebt != null) {
      await DebtService(repository).saveRepaymentTransaction(
        transaction,
        linkedDebt,
        tags,
        importKey: importKey,
      );
      return;
    }

    // 2. New debt disbursement (Cho vay or Vay nợ)
    final targetPerson = person ?? borrower;
    if (targetPerson != null) {
      final direction =
          disbursementDirection ??
          (transaction.text('type') == 'expense'
              ? DebtDirection.lent
              : DebtDirection.borrowed);
      await DebtService(repository).saveDisbursementTransaction(
        transaction,
        targetPerson,
        direction,
        tags,
        importKey: importKey,
      );
      return;
    }

    // 3. Normal transaction
    await repository.saveTransaction(transaction, tags, importKey: importKey);
  }
}
