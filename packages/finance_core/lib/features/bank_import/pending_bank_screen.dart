import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/money.dart';
import '../transactions/transaction_form.dart';
import 'bank_draft.dart';
import 'bank_draft_repository.dart';
import 'bank_providers.dart';

class PendingBankScreen extends ConsumerStatefulWidget {
  const PendingBankScreen({super.key});
  @override
  ConsumerState<PendingBankScreen> createState() => _PendingBankScreenState();
}

class _PendingBankScreenState extends ConsumerState<PendingBankScreen> {
  int offset = 0;
  bool busy = false;
  Future<void> review(BankDraft draft) async {
    setState(() => busy = true);
    try {
      final workspace = await ref.read(workspaceProvider.future);
      if (workspace == null || workspace.repository.userId != draft.owner) {
        return;
      }
      final settings = await ref.read(bankDraftRepositoryProvider).settings();
      final sources = (settings['sources'] as List).cast<Map>();
      final account =
          sources
                  .where((s) => s['code'] == draft.bankCode)
                  .firstOrNull?['account']
              as String?;
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

  Future<void> ignore(BankDraft draft) async {
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
    final drafts = ref.watch(bankDraftPageProvider(offset));
    final count = ref.watch(bankCountProvider).value;
    return Column(
      children: [
        ListTile(
          title: Text(context.tr('Pending transactions')),
          subtitle: Text(
            context.tr(
              'Bank drafts stay on this Android device until you confirm.',
            ),
          ),
          trailing: Text(count?.toString() ?? '…'),
        ),
        Expanded(
          child: drafts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(bankDraftPageProvider),
                child: Text(context.tr('Retry')),
              ),
            ),
            data: (rows) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(bankDraftPageProvider);
                ref.invalidate(bankCountProvider);
                await ref.read(bankDraftPageProvider(offset).future);
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
                                  : '?'}${Money.format(draft.amountMinor, draft.currency)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${draft.bankName} · ${context.dateLabel(draft.occurredAt, time: true)}',
                            ),
                            if (draft.occurredAtSource ==
                                'notification_post_time')
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() => offset -= 100),
                        child: Text(context.tr('Previous')),
                      ),
                      TextButton(
                        onPressed: rows.length < 100
                            ? null
                            : () => setState(() => offset += 100),
                        child: Text(context.tr('Next')),
                      ),
                    ],
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
