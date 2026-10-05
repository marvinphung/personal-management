import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_client/api_client.dart';
import 'package:uuid/uuid.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/money.dart';
import 'bank_confirmation.dart';
import 'bank_providers.dart';

class PendingBankScreen extends ConsumerStatefulWidget {
  const PendingBankScreen({super.key});
  @override
  ConsumerState<PendingBankScreen> createState() => _PendingBankScreenState();
}

class _PendingBankScreenState extends ConsumerState<PendingBankScreen> {
  bool busy = false;
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

  Future<void> review(PendingBankEventDto event) async {
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
          },
          onDiscard: () async {
            await ref.read(apiClientProvider).discardPendingEvent(
              eventId: event.id,
              operationId: const Uuid().v4(),
            );
            ref.invalidate(pendingBankEventsProvider);
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

  Future<void> ignore(PendingBankEventDto event) async {
    setState(() => busy = true);
    try {
      await ref.read(apiClientProvider).discardPendingEvent(
        eventId: event.id,
        operationId: const Uuid().v4(),
      );
      ref.invalidate(pendingBankEventsProvider);
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
    final drafts = ref.watch(pendingBankEventsProvider);
    final count = drafts.value?.length;
    return Column(
      children: [
        ListTile(
          title: Text(context.tr('Pending transactions')),
          subtitle: Text(
            'Đồng bộ an toàn từ máy nhận thông báo ngân hàng.',
          ),
          trailing: Text(count?.toString() ?? '…'),
        ),
        Expanded(
          child: drafts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(pendingBankEventsProvider),
                child: Text(context.tr('Retry')),
              ),
            ),
            data: (rows) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pendingBankEventsProvider);
                await ref.read(pendingBankEventsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.tr('All caught up')),
                    ),
                  for (final draft in rows)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${draft.direction == 'income'
                                  ? '+'
                                  : draft.direction == 'expense'
                                  ? '−'
                                  : '?'}${Money.format(draft.amountVnd, 'VND')}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${draft.bankCode.toUpperCase()} · ${context.dateLabel(DateTime.parse(draft.occurredAt).toLocal(), time: true)}',
                            ),
                            if (draft.timeSource ==
                                'notification_post_time')
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
                                  onPressed: busy ? null : () => ignore(draft),
                                  child: Text(context.tr('Ignore')),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: busy ? null : () => review(draft),
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
        ),
      ],
    );
  }
}
