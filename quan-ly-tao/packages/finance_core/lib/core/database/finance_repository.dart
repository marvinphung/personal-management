import 'dart:convert';
import 'package:drift/drift.dart' show Variable;
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';
import '../utils/ledger.dart';
import '../utils/money.dart';
import '../utils/tag_name.dart';
import 'local_database.dart';
import 'record.dart';

class FinanceRepository {
  final LocalDatabase db;
  final String userId;
  final Lock lock = Lock();
  FinanceRepository(this.db, this.userId);
  Record create(Entity entity, Map<String, dynamic> data, {String? id}) =>
      Record.create(entity, userId, {
        ...data,
        if (entity == Entity.categories &&
            data['name'] == 'Cho vay' &&
            (data['type'] ?? 'expense') == 'expense')
          'behavior': 'lending',
      }, id: id);
  Future<void> save(Record record) => saveBatch([record]);
  Future<void> saveBatch(List<Record> records, {String? importKey}) =>
      lock.synchronized(() => _saveBatch(records, importKey: importKey));

  Future<void> _saveBatch(List<Record> records, {String? importKey}) async {
    // Receipt and outbox are committed atomically. A retry never overwrites an
    // already confirmed transaction, including one edited or deleted later.
    if (importKey != null) {
      if (await db.metadata(importKey) != null) return;
      final transaction = records.firstWhere(
        (r) => r.entity == Entity.transactions,
      );
      if (await db.get(Entity.transactions, transaction.id) != null) return;
    }
    final mutation = const Uuid().v4(),
        now = DateTime.now().toUtc().toIso8601String();
    final rows = records
        .map(
          (r) => r.patch({
            'user_id': userId,
            'client_modified_at': now,
            'updated_at': now,
            'mutation_id': mutation,
          }),
        )
        .toList();
    for (final row in rows) {
      await validate(row, rows);
    }
    await db.enqueue(mutation, rows, receipt: importKey);
  }

  Future<void> applyBankBalance(Map<String, dynamic> snapshot) =>
      lock.synchronized(() async {
        final id = snapshot['account'] as String;
        final amount = snapshot['amount'] as int;
        final at = DateTime.fromMillisecondsSinceEpoch(
          snapshot['at'] as int,
          isUtc: true,
        );
        final account = await db.get(Entity.accounts, id);
        if (account == null ||
            account.deleted ||
            account.text('user_id') != userId ||
            account.text('currency') != snapshot['currency'] ||
            amount.abs() > Money.maxMinor) {
          return;
        }
        final old = DateTime.tryParse(account.text('bank_balance_at'));
        if (old != null && !at.isAfter(old)) return;
        await _saveBatch([
          account.patch({
            'bank_balance': amount,
            'bank_balance_at': at.toIso8601String(),
          }),
        ]);
      });

  Future<void> rememberSelections(String account, String? category) async {
    await db.setMetadata('recent_account', account);
    if (category != null) await db.setMetadata('recent_category', category);
  }

  Future<(String?, String?)> recentSelections() async => (
    await db.metadata('recent_account'),
    await db.metadata('recent_category'),
  );
  Future<List<Record>> accountTransactions(
    String account, {
    DateTime? month,
    int limit = 20,
  }) async {
    final params = <Variable>[
      Variable(account),
      Variable(account),
      Variable(account),
    ];
    var period = '';
    if (month != null) {
      period =
          " AND json_extract(payload,'\$.occurred_at')>=? AND json_extract(payload,'\$.occurred_at')<?";
      params.addAll([
        Variable(DateTime(month.year, month.month).toUtc().toIso8601String()),
        Variable(
          DateTime(month.year, month.month + 1).toUtc().toIso8601String(),
        ),
      ]);
    }
    params.add(Variable(limit));
    final rows = await db
        .customSelect(
          "SELECT payload FROM records WHERE entity='transactions' AND json_extract(payload,'\$.deleted_at') IS NULL AND (json_extract(payload,'\$.account_id')=? OR json_extract(payload,'\$.from_account_id')=? OR json_extract(payload,'\$.to_account_id')=?)$period ORDER BY json_extract(payload,'\$.occurred_at') DESC LIMIT ?",
          variables: params,
        )
        .get();
    return rows
        .map(
          (r) => Record(
            Entity.transactions,
            jsonDecode(r.read<String>('payload')),
          ),
        )
        .toList();
  }

  Future<void> validate(Record row, List<Record> batch) async {
    Future<Record> related(Entity entity, String id) async {
      final local =
          batch.where((r) => r.entity == entity && r.id == id).firstOrNull ??
          await db.get(entity, id);
      if (local == null || local.deleted || local.text('user_id') != userId) {
        throw const FormatException(
          'A related record is unavailable. Sync and try again.',
        );
      }
      return local;
    }

    if (row.text('user_id') != userId) {
      throw const FormatException('Invalid record owner');
    }
    if (row.deleted) return;
    if ([
          Entity.accounts,
          Entity.categories,
          Entity.tags,
          Entity.people,
        ].contains(row.entity) &&
        row.text('name').trim().isEmpty) {
      throw const FormatException('Name is required');
    }
    if (row.entity == Entity.notes && row.text('title').trim().isEmpty) {
      throw const FormatException('Title is required');
    }
    for (final key in ['amount', 'principal_amount']) {
      if (row.data.containsKey(key) &&
          (row.money(key) <= 0 || row.money(key) > Money.maxMinor)) {
        throw const FormatException('Amount must be positive');
      }
    }
    if ([Entity.tags, Entity.categories].contains(row.entity)) {
      final existing = await db.list(row.entity);
      if (existing.any(
        (r) =>
            r.id != row.id &&
            r.text('name').toLowerCase() == row.text('name').toLowerCase() &&
            (row.entity != Entity.categories ||
                r.text('type') == row.text('type')),
      )) {
        throw const FormatException('This name already exists');
      }
    }
    if (row.entity == Entity.tags) {
      if (row.text('category_id').isEmpty) {
        throw const FormatException('Choose a category for this tag');
      }
      await related(Entity.categories, row.text('category_id'));
      if (normalizeTagName(row.text('name')) != row.text('name') ||
          row.text('name').length > 80) {
        throw const FormatException('Use an unaccented tag without spaces');
      }
    }
    if (row.entity == Entity.transactions) {
      final type = row.text('type');
      if (row.data['installment_group'] != null &&
          (type != 'expense' || row.text('purpose') != 'normal')) {
        throw const FormatException('Installments require a normal expense');
      }
      if (!TransactionType.values.any((v) => v.name == type)) {
        throw const FormatException('Choose a transaction type');
      }
      if (type == 'transfer') {
        if (row.data['account_id'] != null ||
            row.text('from_account_id') == row.text('to_account_id')) {
          throw const FormatException('Choose two different accounts');
        }
        final from = await related(
              Entity.accounts,
              row.text('from_account_id'),
            ),
            to = await related(Entity.accounts, row.text('to_account_id'));
        if (from.text('currency') != to.text('currency') ||
            from.text('currency') != row.text('currency')) {
          throw const FormatException('Transfers require matching currencies');
        }
      } else {
        if (row.data['from_account_id'] != null ||
            row.data['to_account_id'] != null) {
          throw const FormatException('Invalid account selection');
        }
        final account = await related(Entity.accounts, row.text('account_id'));
        if (account.text('currency') != row.text('currency')) {
          throw const FormatException('Account currency does not match');
        }
      }
      if (row.data['category_id'] != null) {
        final c = await related(Entity.categories, row.text('category_id'));
        if (c.text('behavior') == 'lending') {
          final debts = [
            ...batch.where((r) => r.entity == Entity.debts),
            ...await db.list(Entity.debts),
          ];
          if (row.text('purpose') != 'debt_disbursement' ||
              !debts.any(
                (d) =>
                    !d.deleted &&
                    d.text('linked_transaction_id') == row.id &&
                    d.text('direction') == 'lent' &&
                    d.money('principal_amount') == row.money('amount') &&
                    d.text('currency') == row.text('currency'),
              )) {
            throw const FormatException(
              'Choose a borrower to create a linked debt',
            );
          }
        }
        if (c.text('type') != 'both' && c.text('type') != type) {
          throw const FormatException('Choose a matching category');
        }
      }
    }
    if (row.entity == Entity.debts) {
      await related(Entity.people, row.text('person_id'));
    }
    if (row.entity == Entity.debtPayments) {
      final debt = await related(Entity.debts, row.text('debt_id'));
      if (debt.text('status') == 'cancelled') {
        throw const FormatException('This debt is cancelled');
      }
      final payments = await db.list(Entity.debtPayments);
      final other = payments.where((p) => p.id != row.id);
      if (row.money('amount') > Ledger.remaining(debt, other)) {
        throw const FormatException('Repayment exceeds the remaining debt');
      }
    }
  }

  Future<void> remove(Record record) async {
    if (record.entity == Entity.transactions &&
        record.text('purpose') != 'normal') {
      throw const FormatException('Manage this cash movement from its debt');
    }
    await save(
      record.patch({'deleted_at': DateTime.now().toUtc().toIso8601String()}),
    );
  }

  Future<void> saveTransaction(
    Record transaction,
    List<Record> tags, {
    String? importKey,
    List<Record> relatedRecords = const [],
  }) async {
    final links = await db.list(Entity.transactionTags);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Record>[transaction, ...relatedRecords];
    for (final tag in tags) {
      if (await db.get(Entity.tags, tag.id) == null) rows.insert(0, tag);
    }
    for (final link in links.where(
      (l) => l.text('transaction_id') == transaction.id,
    )) {
      if (!tags.any((t) => t.id == link.text('tag_id'))) {
        rows.add(link.patch({'deleted_at': now}));
      }
    }
    for (final tag in tags) {
      final id = const Uuid().v5(
        Namespace.url.value,
        'finance:${transaction.id}:${tag.id}',
      );
      final existing = await db.get(Entity.transactionTags, id);
      rows.add(
        (existing ??
                create(Entity.transactionTags, {
                  'transaction_id': transaction.id,
                  'tag_id': tag.id,
                }, id: id))
            .patch({'deleted_at': null}),
      );
    }
    await saveBatch(rows, importKey: importKey);
  }
}
