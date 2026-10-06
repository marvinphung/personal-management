import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_client/api_client.dart';
import 'package:uuid/uuid.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
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
            final opId = const Uuid().v5(Namespace.url.value, 'accept:${event.id}');
            final txId = const Uuid().v5(Namespace.url.value, 'tx:${event.id}');
            await ref.read(apiClientProvider).acceptPendingEvent(
              eventId: event.id,
              operationId: opId,
              transactionId: txId,
              categoryId: categoryId,
              tagIds: tagIds,
              userNote: note,
            );
            ref.invalidate(pendingBankEventsProvider);
            if (mounted) {
              message(context, context.tr('Đã duyệt; đang cập nhật dữ liệu...'));
            }
            final workspace = await ref.read(workspaceProvider.future);
            if (workspace != null) {
              try {
                await workspace.sync.sync();
              } catch (_) {
                // Background sync will retry
              }
              ref.invalidate(monthTransactionsProvider);
              ref.invalidate(balanceProvider);
              ref.invalidate(recordsProvider(Entity.transactions));
              ref.invalidate(recordsProvider(Entity.transactionTags));
              ref.invalidate(recordsProvider(Entity.accounts));
            }
          },
          onDiscard: () async {
            final opId = const Uuid().v5(Namespace.url.value, 'discard:${event.id}');
            await ref.read(apiClientProvider).discardPendingEvent(
              eventId: event.id,
              operationId: opId,
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
      final opId = const Uuid().v5(Namespace.url.value, 'discard:${event.id}');
      await ref.read(apiClientProvider).discardPendingEvent(
        eventId: event.id,
        operationId: opId,
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
    final colors = context.colors;
    final remoteAsync = ref.watch(pendingBankEventsProvider);
    final localAsync = ref.watch(bankDraftPageProvider(offset));
    final localDrafts = localAsync.value ?? [];
    final remoteRows = remoteAsync.value ?? [];
    final hasRemote = remoteRows.isNotEmpty;
    final hasLocal = localDrafts.isNotEmpty;
    final totalCount = hasRemote ? remoteRows.length : localDrafts.length;

    final isLoading = (remoteAsync.isLoading && !remoteAsync.hasValue) && (localAsync.isLoading && !localAsync.hasValue);
    final isError = remoteAsync.hasError && !remoteAsync.hasValue && !hasLocal;

    return RefreshIndicator(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inbox_rounded, color: colors.primaryAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Pending transactions'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasRemote
                            ? 'Đồng bộ từ máy nhận thông báo ngân hàng.'
                            : context.tr('Bank drafts stay on this Android device until you confirm.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      totalCount.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Loading state
          if (isLoading) ...[
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5, color: colors.primaryAccent),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('Đang tải danh sách biến động...'),
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ]
          // Error state
          else if (isError) ...[
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: colors.warning),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('Could not load bank notifications.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ref.invalidate(pendingBankEventsProvider);
                        ref.invalidate(bankDraftPageProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.tr('Retry')),
                    ),
                  ],
                ),
              ),
            ),
          ]
          // Empty state
          else if (!hasRemote && !hasLocal) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.primaryAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.done_all_rounded, size: 32, color: colors.primaryAccent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('All caught up'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('No pending transactions to review.'),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
          // Remote items
          else if (hasRemote) ...[
            for (final draft in remoteRows)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.bgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Text(
                              draft.bankCode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.dateLabel(DateTime.parse(draft.occurredAt).toLocal(), time: true),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MoneyText(
                        amountMinor: draft.amountVnd,
                        currency: 'VND',
                        direction: draft.direction,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (draft.bankDescription.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          draft.bankDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (draft.timeSource == 'notification_post_time') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: colors.warning),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                context.tr('Time uses notification arrival; please review.'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton(
                            onPressed: busy ? null : () => ignoreRemote(draft),
                            child: Text(
                              context.tr('Ignore'),
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                          FilledButton(
                            onPressed: busy ? null : () => reviewRemote(draft),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primaryAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(context.tr('Review & confirm')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ]
          // Local items (Android device receiver)
          else if (hasLocal) ...[
            for (final draft in localDrafts)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.bgElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Text(
                              draft.bankName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.dateLabel(draft.occurredAt, time: true),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MoneyText(
                        amountMinor: draft.amountMinor,
                        currency: draft.currency,
                        direction: draft.direction,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (draft.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          draft.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (draft.occurredAtSource == 'notification_post_time') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 13, color: colors.warning),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                context.tr('Time uses notification arrival; please review.'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          TextButton(
                            onPressed: busy ? null : () => ignoreLocal(draft),
                            child: Text(
                              context.tr('Ignore'),
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                          FilledButton(
                            onPressed: busy ? null : () => reviewLocal(draft),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primaryAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(context.tr('Review & confirm')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
