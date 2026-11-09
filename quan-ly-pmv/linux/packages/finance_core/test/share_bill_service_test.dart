import 'package:finance_core/features/bank_import/bank_draft.dart';
import 'package:finance_core/features/bank_import/bank_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/share_bill/share_bill_service.dart';

void main() {
  late LocalDatabase db;
  late FinanceRepository repo;
  late ShareBillService service;
  late Record account, expense, income;
  setUp(() async {
    db = LocalDatabase.memory();
    repo = FinanceRepository(db, 'user');
    service = ShareBillService(repo);
    account = repo.create(Entity.accounts, {'name': 'Cash'});
    await repo.save(account);
    Record tx(String type, int amount) => repo.create(Entity.transactions, {
      'type': type,
      'amount': amount,
      'account_id': account.id,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
    expense = tx('expense', 600000);
    income = tx('income', 100000);
    await service.saveExpenseWithShareBill(
      transaction: expense,
      tags: [],
      numPeople: 3,
    );
  });
  tearDown(() async {
    await db.close();
  });
  Future<Record> bill() async => (await db.list(Entity.shareBills)).single;
  test(
    'received amounts and represented people are independent; edit is idempotent',
    () async {
      final b = await bill();
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
        peopleCount: 2,
      );
      expect((await bill()).money('num_paid'), 3);
      await service.saveIncomeWithShareBillPayment(
        transaction: income.patch({'amount': 250000}),
        tags: [],
        shareBillId: b.id,
        peopleCount: 1,
      );
      expect((await bill()).money('num_paid'), 2);
      final payments = await db.list(Entity.shareBillPayments);
      expect(payments.length, 1);
      expect(payments.single.money('amount'), 250000);
      expect(ShareBillTotals.received(payments, b.id), 250000);
      await service.saveExpenseWithShareBill(
        transaction: expense.patch({'amount': 700000}),
        tags: [],
        numPeople: 4,
      );
      expect((await bill()).money('num_paid'), 2);
      expect((await bill()).money('total_amount'), 700000);
      await service.removePayment(payments.single);
      expect((await bill()).money('num_paid'), 1);
    },
  );
  test('currency mismatch and zero people leave no partial records', () async {
    final b = await bill();
    await expectLater(
      service.saveIncomeWithShareBillPayment(
        transaction: income.patch({'currency': 'USD'}),
        tags: [],
        shareBillId: b.id,
      ),
      throwsFormatException,
    );
    await expectLater(
      service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
        peopleCount: 0,
      ),
      throwsFormatException,
    );
    expect(await db.list(Entity.shareBillPayments), isEmpty);
    expect(await db.get(Entity.transactions, income.id), isNull);
  });
  test(
    'editing final payment can reopen auto completed bill; manual completion stays',
    () async {
      final b = await bill();
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
        peopleCount: 3,
      );
      expect((await bill()).text('status'), 'completed');
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
        peopleCount: 1,
      );
      expect((await bill()).text('status'), 'active');
      await service.markCompleted(await bill());
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
        peopleCount: 2,
      );
      expect((await bill()).text('status'), 'completed');
      await service.removePayment(
        (await db.list(Entity.shareBillPayments)).single,
      );
      expect((await bill()).text('status'), 'completed');
    },
  );
  test('bank confirmation retry counts represented people once', () async {
    final b = await bill();
    final draft = BankDraft.fromMap({
      'id': 'test',
      'owner': 'user',
      'fingerprint': 'bank-share',
      'bankCode': 'mbbank',
      'currency': 'VND',
      'currencyScale': 0,
      'direction': 'income',
      'amountMinor': 100000,
      'occurredAtMillis': DateTime.now().millisecondsSinceEpoch,
      'occurredAtSource': 'notification_post_time',
    });
    final tx = draft.toTransaction(repo, accountId: account.id);
    await BankConfirmation.save(
      repo,
      draft,
      tx,
      [],
      shareBillId: b.id,
      shareBillPeople: 2,
    );
    await BankConfirmation.save(
      repo,
      draft,
      tx,
      [],
      shareBillId: b.id,
      shareBillPeople: 2,
    );
    expect((await bill()).money('num_paid'), 3);
    expect(await db.list(Entity.shareBillPayments), hasLength(1));
  });
  test(
    'default expense people is one; changing expected count reopens automatic completion',
    () async {
      await service.saveExpenseWithShareBill(transaction: expense, tags: []);
      expect((await bill()).money('num_people'), 1);
      await service.saveExpenseWithShareBill(
        transaction: expense,
        tags: [],
        numPeople: 2,
      );
      final b = await bill();
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
      );
      expect((await bill()).text('status'), 'completed');
      await service.saveExpenseWithShareBill(
        transaction: expense,
        tags: [],
        numPeople: 3,
      );
      expect((await bill()).text('status'), 'active');
      expect((await bill()).money('num_paid'), 2);
    },
  );
  test(
    'payer starts at one and initial paid people can be edited without losing receipts',
    () async {
      expect((await bill()).money('num_paid'), 1);
      final b = await bill();
      await service.saveIncomeWithShareBillPayment(
        transaction: income,
        tags: [],
        shareBillId: b.id,
      );
      expect((await bill()).money('num_paid'), 2);
      await service.saveExpenseWithShareBill(
        transaction: expense,
        tags: [],
        numPeople: 5,
        paidPeople: 3,
      );
      expect((await bill()).money('num_paid'), 3);
      await service.removePayment(
        (await db.list(Entity.shareBillPayments)).single,
      );
      expect((await bill()).money('num_paid'), 2);
      expect((await bill()).money('num_people'), 5);
      await expectLater(
        service.saveExpenseWithShareBill(
          transaction: expense,
          tags: [],
          numPeople: 5,
          paidPeople: 0,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'bank expense share bill retry preserves category tags and source once',
    () async {
      final category = repo.create(Entity.categories, {
        'name': 'Test housing',
        'type': 'expense',
      });
      final tag = repo.create(Entity.tags, {
        'name': 'testrent',
        'category_id': category.id,
      });
      await repo.saveBatch([category, tag]);
      final draft = BankDraft.fromMap({
        'id': 'expense-test',
        'owner': 'user',
        'fingerprint': 'bank-expense-share',
        'bankCode': 'mbbank',
        'currency': 'VND',
        'currencyScale': 0,
        'direction': 'expense',
        'amountMinor': 800000,
        'occurredAtMillis': DateTime.now().millisecondsSinceEpoch,
        'occurredAtSource': 'notification_post_time',
      });
      final tx = draft.toTransaction(repo, accountId: account.id).patch({
        'category_id': category.id,
      });
      await BankConfirmation.save(
        repo,
        draft,
        tx,
        [tag],
        createShareBill: true,
        shareBillPeople: 2,
      );
      await BankConfirmation.save(
        repo,
        draft,
        tx,
        [tag],
        createShareBill: true,
        shareBillPeople: 2,
      );
      final bills = (await db.list(
        Entity.shareBills,
      )).where((b) => b.text('expense_tx_id') == tx.id).toList();
      expect(bills, hasLength(1));
      expect(bills.single.money('num_people'), 2);
      expect(bills.single.money('num_paid'), 1);
      final saved = (await db.get(Entity.transactions, tx.id))!;
      expect(saved.money('amount'), 800000);
      expect(saved.text('category_id'), category.id);
      expect(saved.data['bank_source'], tx.data['bank_source']);
      expect(
        (await db.list(Entity.transactionTags))
            .where((l) => l.text('transaction_id') == tx.id)
            .single
            .text('tag_id'),
        tag.id,
      );
    },
  );
}
