import 'package:uuid/uuid.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

class ShareBillService {
  final FinanceRepository repository;
  ShareBillService(this.repository);

  /// Creates a share bill expense and its linked share_bills record atomically.
  Future<void> saveExpenseWithShareBill({
    required Record transaction,
    required List<Record> tags,
    required int numPeople,
    String? importKey,
  }) async {
    if (transaction.text('type') != 'expense') {
      throw const FormatException('Share bill chỉ áp dụng cho giao dịch chi tiêu');
    }
    final shareBillId = const Uuid().v5(
      Namespace.url.value,
      'finance:sharebill:${transaction.id}',
    );
    final shareBill = repository.create(Entity.shareBills, {
      'expense_tx_id': transaction.id,
      'total_amount': transaction.money('amount'),
      'currency': transaction.text('currency'),
      'num_people': numPeople,
      'num_paid': 0,
      'status': 'active',
    }, id: shareBillId);

    await repository.saveTransaction(
      transaction,
      tags,
      relatedRecords: [shareBill],
      importKey: importKey,
    );
  }

  /// Links an income transaction to an existing share bill and auto-completes
  /// the bill when the payment count reaches num_people.
  Future<void> saveIncomeWithShareBillPayment({
    required Record transaction,
    required List<Record> tags,
    required String shareBillId,
  }) async {
    if (transaction.text('type') != 'income') {
      throw const FormatException('Nhận share bill phải là giao dịch thu nhập');
    }
    final shareBill = await repository.db.get(Entity.shareBills, shareBillId);
    if (shareBill == null || shareBill.deleted) {
      throw const FormatException('Không tìm thấy Share Bill này');
    }
    if (shareBill.text('status') == 'completed') {
      throw const FormatException('Share Bill này đã hoàn tất');
    }

    final paymentId = const Uuid().v5(
      Namespace.url.value,
      'finance:sbpayment:${transaction.id}',
    );
    final payment = repository.create(Entity.shareBillPayments, {
      'share_bill_id': shareBillId,
      'income_tx_id': transaction.id,
      'amount': transaction.money('amount'),
      'paid_at': transaction.text('occurred_at'),
    }, id: paymentId);

    final newNumPaid = shareBill.money('num_paid') + 1;
    final isComplete = newNumPaid >= shareBill.money('num_people');
    final updatedBill = shareBill.patch({
      'num_paid': newNumPaid,
      if (isComplete) 'status': 'completed',
      if (isComplete) 'completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    await repository.saveTransaction(
      transaction,
      tags,
      relatedRecords: [payment, updatedBill],
    );
  }

  /// Manually marks a share bill as completed without adding any payment.
  Future<void> markCompleted(Record shareBill) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await repository.saveBatch([
      shareBill.patch({'status': 'completed', 'completed_at': now}),
    ]);
  }

  /// Removes a payment and decrements the share bill counter, restoring active
  /// status if the bill was auto-completed by this payment.
  Future<void> removePayment(Record payment) async {
    final deleted = DateTime.now().toUtc().toIso8601String();
    final cash = await repository.db.get(
      Entity.transactions,
      payment.text('income_tx_id'),
    );
    final bill = await repository.db.get(
      Entity.shareBills,
      payment.text('share_bill_id'),
    );
    final rows = <Record>[payment.patch({'deleted_at': deleted})];
    if (cash != null) rows.add(cash.patch({'deleted_at': deleted}));
    if (bill != null && !bill.deleted) {
      final newPaid = (bill.money('num_paid') - 1).clamp(0, 9999);
      rows.add(bill.patch({
        'num_paid': newPaid,
        if (bill.text('status') == 'completed' &&
            newPaid < bill.money('num_people'))
          'status': 'active',
        if (bill.text('status') == 'completed' &&
            newPaid < bill.money('num_people'))
          'completed_at': null,
      }));
    }
    await repository.saveBatch(rows);
  }
}
