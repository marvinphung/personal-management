import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/app/providers.dart';
import 'package:finance_core/core/database/local_database.dart';
import 'package:finance_core/core/database/finance_repository.dart';
import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/core/sync/sync_engine.dart';
import 'repository_test.dart' show FakeRemote;
import 'widget_test.dart' show TestWorkspace;

void main() {
  test(
    'successive local saves refresh lists, balances and pending changes',
    () async {
      final db = LocalDatabase.memory();
      final repo = FinanceRepository(db, 'user');
      final workspace = UserWorkspace(
        db,
        repo,
        SyncEngine(db, FakeRemote()..offline = true),
      );
      final container = ProviderContainer(
        overrides: [
          workspaceProvider.overrideWith(() => TestWorkspace(workspace)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await workspace.close();
      });
      container.listen(recordsProvider(Entity.accounts), (_, _) {});
      container.listen(monthTransactionsProvider, (_, _) {});
      container.listen(balanceProvider, (_, _) {});
      container.listen(pendingProvider, (_, _) {});
      await container.read(recordsProvider(Entity.accounts).future);
      await container.pump();
      // Initial sync must not swallow notifications from later local saves.
      await db.mergeRemote([]);
      await container.pump();
      final account = repo.create(Entity.accounts, {'name': 'MB Bank'});
      await repo.save(account);
      await container.pump();
      expect(
        (await container.read(
          recordsProvider(Entity.accounts).future,
        )).map((r) => r.id),
        [account.id],
      );
      final savings = repo.create(Entity.accounts, {'name': 'Savings'});
      await repo.save(savings);
      await container.pump();
      expect(
        await container.read(recordsProvider(Entity.accounts).future),
        hasLength(2),
      );
      for (final amount in [45000, 72000]) {
        await repo.save(
          repo.create(Entity.transactions, {
            'type': 'expense',
            'amount': amount,
            'account_id': account.id,
            'description': 'Expense',
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        await container.pump();
      }
      expect(
        await container.read(monthTransactionsProvider.future),
        hasLength(2),
      );
      expect(
        (await container.read(balanceProvider.future))[account.id],
        -117000,
      );
      expect(await container.read(pendingProvider.future), hasLength(4));
    },
  );
}
