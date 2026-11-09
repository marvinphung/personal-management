import 'package:uuid/uuid.dart';
import '../../core/database/finance_repository.dart';
import '../../core/database/record.dart';

class ShareBillTotals {
  static int people(Record payment) =>
      payment.data['people_count'] as int? ?? 1;
  static int initialPaid(Record bill) =>
      bill.data['initial_paid_people'] as int? ?? 1;
  static int received(Iterable<Record> payments, String billId) => payments
      .where((p) => !p.deleted && p.text('share_bill_id') == billId)
      .fold(0, (sum, p) => sum + p.money('amount'));
}

class ShareBillService {
  final FinanceRepository repository;
  ShareBillService(this.repository);
  String get _now => DateTime.now().toUtc().toIso8601String();

  Record _progress(Record bill, Iterable<Record> payments) {
    final count = payments
        .where((p) => !p.deleted && p.text('share_bill_id') == bill.id)
        .fold(
          ShareBillTotals.initialPaid(bill),
          (sum, p) => sum + ShareBillTotals.people(p),
        );
    // Legacy manually completed bills have no marker but fewer than expected people.
    final manual =
        bill.data['manual_completed_at'] ??
        (!bill.data.containsKey('manual_completed_at') &&
                bill.text('status') == 'completed' &&
                bill.money('num_paid') < bill.money('num_people')
            ? bill.data['completed_at']
            : null);
    final complete = manual != null || count >= bill.money('num_people');
    return bill.patch({
      'num_paid': count,
      'status': complete ? 'completed' : 'active',
      'manual_completed_at': manual,
      'completed_at': complete ? (bill.data['completed_at'] ?? _now) : null,
    });
  }

  Future<void> saveExpenseWithShareBill({
    required Record transaction,
    required List<Record> tags,
    int numPeople = 1,
    int? paidPeople,
    String? importKey,
  }) async {
    if (transaction.text('type') != 'expense' || numPeople < 1) {
      throw const FormatException(
        'Chi tiêu Share Bill cần số người ít nhất là 1.',
      );
    }
    final existing = (await repository.db.list(Entity.shareBills))
        .where((b) => b.text('expense_tx_id') == transaction.id && !b.deleted)
        .firstOrNull;
    final payments = await repository.db.list(Entity.shareBillPayments);
    if (existing != null &&
        payments.any(
          (p) => !p.deleted && p.text('share_bill_id') == existing.id,
        ) &&
        existing.text('currency') != transaction.text('currency')) {
      throw const FormatException(
        'Không thể đổi tiền tệ của bill đã có lần nhận.',
      );
    }
    final receiptPeople = existing == null
        ? 0
        : payments
              .where(
                (p) => !p.deleted && p.text('share_bill_id') == existing.id,
              )
              .fold(0, (sum, p) => sum + ShareBillTotals.people(p));
    final initialPaid = paidPeople == null
        ? (existing == null ? 1 : ShareBillTotals.initialPaid(existing))
        : paidPeople - receiptPeople;
    if (initialPaid < 1) {
      throw const FormatException(
        'Số người đã trả phải gồm bạn và các lần nhận đã ghi.',
      );
    }
    final bill =
        (existing ??
                repository.create(
                  Entity.shareBills,
                  {},
                  id: const Uuid().v5(
                    Namespace.url.value,
                    'finance:sharebill:${transaction.id}',
                  ),
                ))
            .patch({
              'expense_tx_id': transaction.id,
              'total_amount': transaction.money('amount'),
              'currency': transaction.text('currency'),
              'num_people': numPeople,
              'initial_paid_people': initialPaid,
            });
    // Preserve the manual marker before changing the expected people count.
    final withMarker = existing == null
        ? bill
        : bill.patch({
            'manual_completed_at': _progress(
              existing,
              payments,
            ).data['manual_completed_at'],
          });
    await repository.saveTransaction(
      transaction,
      tags,
      relatedRecords: [_progress(withMarker, payments)],
      importKey: importKey,
    );
  }

  Future<void> saveIncomeWithShareBillPayment({
    required Record transaction,
    required List<Record> tags,
    required String shareBillId,
    int peopleCount = 1,
    String? importKey,
  }) async {
    if (transaction.text('type') != 'income' || peopleCount < 1) {
      throw const FormatException('Nhận Share Bill cần số người ít nhất là 1.');
    }
    final bill = await repository.db.get(Entity.shareBills, shareBillId);
    if (bill == null || bill.deleted) {
      throw const FormatException('Không tìm thấy Share Bill này.');
    }
    if (bill.text('currency') != transaction.text('currency')) {
      throw const FormatException('Tiền tệ giao dịch và Share Bill phải khớp.');
    }
    final payments = await repository.db.list(Entity.shareBillPayments);
    final existing = payments
        .where((p) => p.text('income_tx_id') == transaction.id && !p.deleted)
        .firstOrNull;
    if (bill.text('status') == 'completed' &&
        existing?.text('share_bill_id') != bill.id) {
      throw const FormatException('Share Bill này đã hoàn tất.');
    }
    final payment =
        (existing ??
                repository.create(
                  Entity.shareBillPayments,
                  {},
                  id: const Uuid().v5(
                    Namespace.url.value,
                    'finance:sbpayment:${transaction.id}',
                  ),
                ))
            .patch({
              'share_bill_id': bill.id,
              'income_tx_id': transaction.id,
              'amount': transaction.money('amount'),
              'paid_at': transaction.text('occurred_at'),
              'people_count': peopleCount,
            });
    final updated = [...payments.where((p) => p.id != payment.id), payment];
    final rows = <Record>[payment, _progress(bill, updated)];
    if (existing != null && existing.text('share_bill_id') != bill.id) {
      final old = await repository.db.get(
        Entity.shareBills,
        existing.text('share_bill_id'),
      );
      if (old != null) rows.add(_progress(old, updated));
    }
    await repository.saveTransaction(
      transaction,
      tags,
      relatedRecords: rows,
      importKey: importKey,
    );
  }

  Future<void> markCompleted(Record bill) async {
    final now = _now;
    await repository.save(
      bill.patch({
        'status': 'completed',
        'completed_at': now,
        'manual_completed_at': now,
      }),
    );
  }

  Future<void> removePayment(Record payment) async {
    final cash = await repository.db.get(
      Entity.transactions,
      payment.text('income_tx_id'),
    );
    final bill = await repository.db.get(
      Entity.shareBills,
      payment.text('share_bill_id'),
    );
    final deleted = payment.patch({'deleted_at': _now});
    final payments = await repository.db.list(Entity.shareBillPayments);
    await repository.saveBatch([
      deleted,
      if (cash != null) cash.patch({'deleted_at': deleted.data['deleted_at']}),
      if (bill != null && !bill.deleted)
        _progress(bill, [
          ...payments.where((p) => p.id != payment.id),
          deleted,
        ]),
    ]);
  }
}
