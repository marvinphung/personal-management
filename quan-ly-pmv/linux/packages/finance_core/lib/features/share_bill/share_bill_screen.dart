import '../transactions/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/money.dart';
import 'share_bill_service.dart';

class ShareBillScreen extends ConsumerWidget {
  const ShareBillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final payments =
        ref.watch(recordsProvider(Entity.shareBillPayments)).value ?? [];
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Bill',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Theo dõi bill chia nhóm và nhận lại tiền',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncRecords(
            value: ref.watch(recordsProvider(Entity.shareBills)),
            builder: (bills) {
              if (bills.isEmpty) {
                return const EmptyState(
                  title: 'Chưa có share bill nào',
                  description:
                      'Khi tạo giao dịch chi tiêu, bật "Chia bill với nhóm" để theo dõi tiền nhận lại.',
                  icon: Icons.group_outlined,
                );
              }

              final activeBills = bills.where(
                (b) =>
                    b.text('currency') == currency &&
                    b.text('status') != 'completed',
              );
              final completedBills = bills.where(
                (b) =>
                    b.text('currency') == currency &&
                    b.text('status') == 'completed',
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  if (activeBills.isNotEmpty) ...[
                    _SectionHeader(title: 'Đang chờ nhận'),
                    for (final b in activeBills)
                      _ShareBillCard(
                        bill: b,
                        payments: payments,
                        onTap: () => _showDetail(context, ref, b, payments),
                      ),
                  ],
                  if (completedBills.isNotEmpty) ...[
                    _SectionHeader(title: 'Đã hoàn tất'),
                    for (final b in completedBills)
                      _ShareBillCard(
                        bill: b,
                        payments: payments,
                        onTap: () => _showDetail(context, ref, b, payments),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(
    BuildContext context,
    WidgetRef ref,
    Record bill,
    List<Record> payments,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareBillDetail(bill: bill, payments: payments),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: context.colors.textSecondary,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareBillCard
// ─────────────────────────────────────────────────────────────────────────────

class _ShareBillCard extends StatelessWidget {
  final Record bill;
  final List<Record> payments;
  final VoidCallback onTap;

  const _ShareBillCard({
    required this.bill,
    required this.payments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numPaid = bill.money('num_paid');
    final numPeople = bill.money('num_people');
    final isCompleted = bill.text('status') == 'completed';
    final total = bill.money('total_amount');
    final currency = bill.text('currency');

    final received = ShareBillTotals.received(payments, bill.id);
    final remaining = total - received;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.bgElevated
                      : colors.income.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_outline_rounded
                      : Icons.group_outlined,
                  color: isCompleted ? colors.textMuted : colors.income,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Money.format(total, currency),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$numPaid/$numPeople người đã trả',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: numPeople > 0
                          ? (numPaid / numPeople).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: colors.bgElevated,
                      color: isCompleted ? colors.income : colors.primaryAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!isCompleted)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Chi − nhận lại',
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                    Text(
                      Money.format(remaining, currency),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.warning,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareBillDetail — bottom sheet chi tiết
// ─────────────────────────────────────────────────────────────────────────────

class _ShareBillDetail extends ConsumerWidget {
  final Record bill;
  final List<Record> payments;

  const _ShareBillDetail({required this.bill, required this.payments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final allPayments =
        ref.watch(recordsProvider(Entity.shareBillPayments)).value ?? payments;
    final myPayments = allPayments
        .where((p) => !p.deleted && p.text('share_bill_id') == bill.id)
        .toList();
    final numPaid = bill.money('num_paid');
    final numPeople = bill.money('num_people');
    final total = bill.money('total_amount');
    final currency = bill.text('currency');

    final isCompleted = bill.text('status') == 'completed';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderProminent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Money.format(total, currency),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '$numPaid/$numPeople người đã trả',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa Share Bill',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final formContext = Navigator.of(context).context;
                    final w = await ref.read(workspaceProvider.future);
                    final tx = await w?.repository.db.get(
                      Entity.transactions,
                      bill.text('expense_tx_id'),
                    );
                    if (!context.mounted ||
                        !formContext.mounted ||
                        tx == null) {
                      return;
                    }
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (formContext.mounted) {
                      showTransactionForm(formContext, record: tx);
                    }
                  },
                ),
                if (!isCompleted)
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(workspaceProvider.future).then((w) async {
                        if (w != null) {
                          await ShareBillService(
                            w.repository,
                          ).markCompleted(bill);
                        }
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Hoàn tất'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: LinearProgressIndicator(
              value: numPeople > 0 ? (numPaid / numPeople).clamp(0.0, 1.0) : 0,
              backgroundColor: colors.bgElevated,
              color: isCompleted ? colors.income : colors.primaryAccent,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Đã nhận: ${Money.format(ShareBillTotals.received(myPayments, bill.id), currency)} · Chi − nhận lại: ${Money.format(total - ShareBillTotals.received(myPayments, bill.id), currency)}',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: myPayments.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có lần nhận nào',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: myPayments.length,
                    itemBuilder: (context, i) {
                      final p = myPayments[i];
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.income.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.south_rounded,
                            color: colors.income,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          Money.format(p.money('amount'), currency),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        subtitle: Text(
                          context.dateLabel(p.date('paid_at')),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        onTap: () async {
                          final formContext = Navigator.of(context).context;
                          final w = await ref.read(workspaceProvider.future);
                          final tx = await w?.repository.db.get(
                            Entity.transactions,
                            p.text('income_tx_id'),
                          );
                          if (!context.mounted ||
                              !formContext.mounted ||
                              tx == null) {
                            return;
                          }
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          if (formContext.mounted) {
                            showTransactionForm(formContext, record: tx);
                          }
                        },
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: colors.textMuted,
                          ),
                          onPressed: () async {
                            final w = await ref.read(workspaceProvider.future);
                            if (w != null) {
                              await ShareBillService(
                                w.repository,
                              ).removePayment(p);
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
