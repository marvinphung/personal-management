import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';
import 'bank_draft.dart';
import '../debts/debt_service.dart';

class BankConfirmation {
  static Future<void> save(
    FinanceRepository repository,
    BankDraft draft,
    Record transaction,
    List<Record> tags, {
    Record? borrower,
  }) async {
    if (repository.userId != draft.owner ||
        transaction.id != draft.transactionId) {
      throw const FormatException('Please sign in again');
    }
    if (borrower != null) {
      await DebtService(repository).saveLendingTransaction(
        transaction,
        borrower,
        tags,
        importKey: 'bank:${draft.fingerprint}',
      );
      return;
    }
    await repository.saveTransaction(
      transaction,
      tags,
      importKey: 'bank:${draft.fingerprint}',
    );
  }
}
