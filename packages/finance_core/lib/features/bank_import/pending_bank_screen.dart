import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_client/api_client.dart';
import 'package:uuid/uuid.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/money.dart';
import '../transactions/transaction_form.dart';
import 'bank_confirmation.dart';
import 'bank_draft.dart';
import 'bank_draft_repository.dart';
import 'bank_providers.dart';

class PendingBankScreen extends ConsumerStatefulWidget {
  const PendingBankScreen({super.key});
  @override
  ConsumerState<PendingBankScreen> createState() => _PendingBankScreenState();
}

class _PendingBankScreenState extends ConsumerState<PendingBankScreen> {
  bool busy = false;
  int offset = 0;

  Record _record(PendingBankEventDto event) => Record(
    Entity.pendingBankEvents,
    {
      'id': event.id,
      'user_id': event.userId,
      'bank_code': event.bankCode,
      'owner_account_snapshot': event.ownerAccountSnapshot,
      'direction': event.direction,
      'amount_vnd': event.amountVnd,
      'occurred_at': event.occurredAt,
      'time_source': event.timeSource,
      'bank_description': event.bankDescription,
    },
  );

  Future<void> reviewRemote(PendingBankEventDto event) async {
    setState(() => busy = true);
    try {
      final categories = await ref.read(recordsProvider(Entity.categories).future);
      final tags = await ref.read(recordsProvider(Entity.tags).future);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => BankEventClassificationSheet(
          pendingEvent: _record(event),
          categories: categories,
          tags: tags,
          onAccept: (categoryId, tagIds, note) async {
            await ref.read(apiClientProvider).acceptPendingEvent(
              eventId: event.id,
              operationId: const Uuid().v4(),
              transactionId: const Uuid().v4(),
              categoryId: categoryId,
              tagIds: tagIds,
              userNote: note,
            );
            ref.invalidate(pendingBankEventsProvider);
            final workspace = await ref.read(workspaceProvider.future);
            if (workspace != null) {
              await workspace.sync.sync();
              ref.invalidate(monthTransactionsProvider);
              ref.invalidate(balanceProvider);
              ref.invalidate(recordsProvider(Entity.transactions));
              ref.invalidate(recordsProvider(Entity.transactionTags));
              ref.invalidate(recordsProvider(Entity.accounts));
            }
          },
          onDiscard: () async {
            await ref.read(apiClientProvider).discardPendingEvent(
              eventId: event.id,
              operationId: const Uuid().v4(),
            );
            ref.invalidate(pendingBankEventsProvider);
            final workspace = await ref.read(workspaceProvider.future);
            if (workspace != null) {
              await workspace.sync.sync();
            }
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        message(
          context,
          context.tr('Could not open the bank inbox. Please retry.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ignoreRemote(PendingBankEventDto event) async {
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).discardPendingEvent(
        eventId: event.id,
        operationId: const Uuid().v4(),
      );
      ref.invalidate(pendingBankEventsProvider);
      final workspace = await ref.read(workspaceProvider.future);
      if (workspace != null) {
        await workspace.sync.sync();
      }
    } catch (_) {
      if (mounted) {
        message(
          context,
          context.tr('Could not update the draft. Please retry.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reviewLocal(BankDraft draft) async {
    setState(() => busy = true);
    try {
      final workspace = await ref.read(workspaceProvider.future);
      if (workspace == null || workspace.repository.userId != draft.owner) {
        return;
      }
      final settings = await ref.read(bankDraftRepositoryProvider).settings();
      final sources = (settings['sources'] as List).cast<Map>();
      final account = sources
          .where((s) => s['code'] == draft.bankCode)
          .firstOrNull?['account'] as String?;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => TransactionForm(
          record: draft.toTransaction(workspace.repository, accountId: account),
          bankDraft: draft,
        ),
      );
    } catch (_) {
      if (mounted) {
        message(
          context,
          context.tr('Could not open the bank inbox. Please retry.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ignoreLocal(BankDraft draft) async {
    setState(() => busy = true);
    try {
      await ref
          .read(bankDraftRepositoryProvider)
          .finish(draft, confirmed: false);
      ref.invalidate(bankDraftPageProvider);
      ref.invalidate(bankCountProvider);
    } catch (_) {
      if (mounted) {
        message(
          context,
          context.tr('Could not update the draft. Please retry.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteAsync = ref.watch(pendingBankEventsProvider);
    final localDrafts = ref.watch(bankDraftPageProvider(offset)).value ?? [];
    final remoteRows = remoteAsync.value ?? [];
    final hasRemote = remoteRows.isNotEmpty;
    final hasLocal = localDrafts.isNotEmpty;
    final totalCount = hasRemote ? remoteRows.length : localDrafts.length;

    return Column(
      children: [
        ListTile(
          title: Text(context.tr('Pending transactions')),
          subtitle: Text(
            hasRemote
                ? 'Đồng bộ an toàn từ máy nhận thông báo ngân hàng.'
                : context.tr(
                    'Bank drafts stay on this Android device until you confirm.',
                  ),
          ),
          trailing: Text(totalCount.toString()),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingBankEventsProvider);
              ref.invalidate(bankDraftPageProvider);
              ref.invalidate(bankCountProvider);
              await Future.wait([
                ref.read(pendingBankEventsProvider.future).catchError((_) => <PendingBankEventDto>[]),
                ref.read(bankDraftPageProvider(offset).future).catchError((_) => <BankDraft>[]),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!hasRemote && !hasLocal)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.tr('All caught up')),
                  ),
                if (hasRemote)
                  for (final draft in remoteRows)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${draft.direction == 'income' ? '+' : draft.direction == 'expense' ? '−' : '?'}${Money.format(draft.amountVnd, 'VND')}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${draft.bankCode.toUpperCase()} · ${context.dateLabel(DateTime.parse(draft.occurredAt).toLocal(), time: true)}',
                            ),
                            if (draft.timeSource == 'notification_post_time')
                              Text(
                                context.tr(
                                  'Time uses notification arrival; please review.',
                                ),
                              ),
                            if (draft.bankDescription.isNotEmpty)
                              Text(draft.bankDescription),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: busy ? null : () => ignoreRemote(draft),
                                  child: Text(context.tr('Ignore')),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: busy ? null : () => reviewRemote(draft),
                                  child: Text(context.tr('Review & confirm')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                else if (hasLocal)
                  for (final draft in localDrafts)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${draft.direction == 'income' ? '+' : draft.direction == 'expense' ? '−' : '?'}${Money.format(draft.amountMinor, draft.currency)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${draft.bankName} · ${context.dateLabel(draft.occurredAt, time: true)}',
                            ),
                            if (draft.occurredAtSource == 'notification_post_time')
                              Text(
                                context.tr(
                                  'Time uses notification arrival; please review.',
                                ),
                              ),
                            if (draft.description.isNotEmpty)
                              Text(draft.description),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: busy ? null : () => ignoreLocal(draft),
                                  child: Text(context.tr('Ignore')),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: busy ? null : () => reviewLocal(draft),
                                  child: Text(context.tr('Review & confirm')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
