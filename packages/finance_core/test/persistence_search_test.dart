import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/search_repository.dart';
import 'package:finance_core/core/database/record.dart';

void main() {
  test(
    'closing and reopening SQLite preserves offline records and outbox',
    () async {
      final directory = await Directory.systemTemp.createTemp('finance-test-');
      final file = File('${directory.path}/cache.sqlite');
      var db = LocalDatabase.file(file);
      final repo = FinanceRepository(db, 'user');
      await repo.save(repo.create(Entity.accounts, {'name': 'MB Bank'}));
      await db.close();
      db = LocalDatabase.file(file);
      expect((await db.list(Entity.accounts)).single.text('name'), 'MB Bank');
      expect(await db.pending(), hasLength(1));
      await db.close();
      await directory.delete(recursive: true);
    },
  );
  test(
    'SQLite search joins tags, categories and people without exposing deleted rows',
    () async {
      final db = LocalDatabase.memory();
      final repo = FinanceRepository(db, 'user');
      final account = repo.create(Entity.accounts, {'name': 'Cash'}),
          category = repo.create(Entity.categories, {'name': 'Food'}),
          tag = repo.create(Entity.tags, {
            'name': 'coffee',
            'category_id': category.id,
          }),
          person = repo.create(Entity.people, {'name': 'Nam'});
      await repo.saveBatch([account, category, person]);
      final tx = repo.create(Entity.transactions, {
        'type': 'expense',
        'amount': 45000,
        'account_id': account.id,
        'category_id': category.id,
        'description': 'Morning drink',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
      await repo.saveTransaction(tx, [tag]);
      final note = repo.create(Entity.notes, {
        'title': 'Repay next week',
        'person_id': person.id,
      });
      await repo.save(note);
      final search = SearchRepository(db);
      expect((await search.search('coffee')).any((r) => r.id == tx.id), true);
      expect((await search.search('Food')).any((r) => r.id == tx.id), true);
      expect((await search.search('Nam')).any((r) => r.id == note.id), true);
      await repo.remove(tx);
      expect((await search.search('coffee')).any((r) => r.id == tx.id), false);
      expect(await search.search("%' OR 1=1 --"), isEmpty);
      await db.close();
    },
  );
  test(
    'rejecting a batch removes never-uploaded rows but retains later local edits',
    () async {
      final db = LocalDatabase.memory();
      final r = FinanceRepository(db, 'user');
      final category = r.create(Entity.categories, {'name': 'Khác'});
      await r.save(category);
      await db.acknowledge((await db.pending()).single.id);
      final tag = r.create(Entity.tags, {
        'name': 'new',
        'category_id': category.id,
      });
      await r.save(tag);
      final op = (await db.pending()).single;
      await db.reject(op);
      expect(await db.list(Entity.tags), isEmpty);
      await r.save(tag);
      final older = (await db.pending()).single;
      await r.save(tag.patch({'name': 'newer'}));
      await db.reject(older);
      expect((await db.list(Entity.tags)).single.text('name'), 'newer');
      expect(await db.pending(), hasLength(1));
      await db.close();
    },
  );
}
