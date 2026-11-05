import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/bank_import/bank_draft.dart';
import 'package:finance_core/features/bank_import/bank_confirmation.dart';

void main() {
  late LocalDatabase db;
  late FinanceRepository repo;
  late Record account;
  final draft = BankDraft.fromMap({
    'id': 'native-id',
    'owner': 'user',
    'fingerprint': 'a' * 64,
    'amountMinor': 1999,
    'currency': 'USD',
    'currencyScale': 2,
    'direction': 'expense',
    'occurredAtMillis': 1790000000000,
    'occurredAtSource': 'notification_post_time',
    'bankCode': 'mbbank',
    'descriptionCandidate': 'Google Service',
  });
  setUp(() async {
    db = LocalDatabase.memory();
    repo = FinanceRepository(db, 'user');
    account = repo.create(Entity.accounts, {
      'name': 'USD account',
      'currency': 'USD',
    });
    await repo.save(account);
  });
  tearDown(() => db.close());
  test(
    'confirmed normalized transaction uses local repository and pending sync',
    () async {
      final row = draft.toTransaction(repo, accountId: account.id);
      await BankConfirmation.save(repo, draft, row, []);
      final saved = (await db.list(Entity.transactions)).single;
      expect(saved.money('amount'), 1999);
      expect(saved.text('description'), isEmpty);
      expect(saved.text('currency'), 'USD');
      expect(saved.data.containsKey('rawContent'), false);
      expect((await db.pending()).last.rows.single.id, row.id);
    },
  );
  test(
    'retry after local commit does not duplicate or overwrite a later edit',
    () async {
      final row = draft.toTransaction(repo, accountId: account.id);
      await Future.wait([
        BankConfirmation.save(repo, draft, row, []),
        BankConfirmation.save(repo, draft, row, []),
      ]);
      expect(await db.list(Entity.transactions), hasLength(1));
      expect(await db.pending(), hasLength(2));
      await repo.save(row.patch({'description': 'Reviewed edit'}));
      await BankConfirmation.save(repo, draft, row, []);
      expect(
        (await db.list(Entity.transactions)).single.text('description'),
        'Reviewed edit',
      );
    },
  );
  test(
    'bank loan confirmation creates one debt with its original currency and time',
    () async {
      final person = repo.create(Entity.people, {'name': 'Nam'});
      final category = repo.create(Entity.categories, {'name': 'Cho vay'});
      await repo.saveBatch([person, category]);
      final tx = draft.toTransaction(repo, accountId: account.id).patch({
        'category_id': category.id,
      });
      await expectLater(
        BankConfirmation.save(repo, draft, tx, []),
        throwsFormatException,
      );
      expect(await db.list(Entity.transactions), isEmpty);
      expect(await db.list(Entity.debts), isEmpty);
      await BankConfirmation.save(repo, draft, tx, [], borrower: person);
      await BankConfirmation.save(repo, draft, tx, [], borrower: person);
      final debt = (await db.list(Entity.debts)).single;
      expect(debt.money('principal_amount'), 1999);
      expect(debt.text('currency'), 'USD');
      expect(debt.text('started_at'), tx.text('occurred_at'));
      expect(debt.text('linked_transaction_id'), tx.id);
      expect(
        (await db.list(Entity.transactions)).single.text('purpose'),
        'debt_disbursement',
      );
    },
  );
  test('invalid save retains eligibility for later retry', () async {
    final row = draft.toTransaction(repo);
    await expectLater(
      BankConfirmation.save(repo, draft, row, []),
      throwsFormatException,
    );
    expect(await db.list(Entity.transactions), isEmpty);
    await BankConfirmation.save(
      repo,
      draft,
      row.patch({'account_id': account.id}),
      [],
    );
    expect(await db.list(Entity.transactions), hasLength(1));
  });
  test('currency mismatch is rejected without conversion', () async {
    final vnd = repo.create(Entity.accounts, {'name': 'VND'});
    await repo.save(vnd);
    await expectLater(
      BankConfirmation.save(
        repo,
        draft,
        draft.toTransaction(repo, accountId: vnd.id),
        [],
      ),
      throwsFormatException,
    );
    expect(await db.list(Entity.transactions), isEmpty);
  });
  test('another finance user cannot confirm the draft', () async {
    final other = FinanceRepository(db, 'other');
    await expectLater(
      BankConfirmation.save(
        other,
        draft,
        draft.toTransaction(repo, accountId: account.id),
        [],
      ),
      throwsFormatException,
    );
  });
}
