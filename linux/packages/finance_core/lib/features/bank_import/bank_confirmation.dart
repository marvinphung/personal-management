import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';
import 'bank_draft.dart';

class BankConfirmation {
  static Future<void> save(
    FinanceRepository repository,
    BankDraft draft,
    Record transaction,
    List<Record> tags,
  ) async {
    if (repository.userId != draft.owner ||
        transaction.id != draft.transactionId) {
      throw const FormatException('Please sign in again');
    }
    await repository.saveTransaction(
      transaction,
      tags,
      importKey: 'bank:${draft.fingerprint}',
    );
  }
}
