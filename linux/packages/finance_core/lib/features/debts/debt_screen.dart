import '../catalog/person_picker.dart';
import '../../core/utils/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/localization/app_language.dart';
import '../../core/utils/ledger.dart';
import '../../core/utils/money.dart';
import '../catalog/catalog_screen.dart';
import 'debt_service.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final payments =
        ref.watch(recordsProvider(Entity.debtPayments)).value ?? [];
    final people = ref.watch(recordsProvider(Entity.people)).value ?? [];
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Công nợ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDebtForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Tạo khoản nợ'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncRecords(
            value: ref.watch(recordsProvider(Entity.debts)),
            builder: (debts) {
              if (debts.isEmpty) {
                return EmptyState(
                  title: 'Chưa có khoản công nợ nào',
                  description:
                      'Ghi lại các khoản cho vay hoặc vay nợ, sau đó thêm các lần thu/trả nợ.',
                  onAdd: () => showDebtForm(context),
                );
              }

              int outstanding(String direction) => debts
                  .where(
                    (d) =>
                        d.text('currency') == currency &&
                        d.text('direction') == direction &&
                        d.text('status') != 'cancelled' &&
                        d.text('status') != 'completed',
                  )
                  .fold(0, (sum, d) => sum + Ledger.remaining(d, payments));

              final sections = [
                ('Cho vay (Người khác nợ tôi)', 'lent', false),
                ('Vay nợ (Tôi nợ người khác)', 'borrowed', false),
                ('Đã hoàn tất', '', true),
              ];

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final (title, dir, isCompleted) in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (!isCompleted)
                            Text(
                              Money.format(outstanding(dir), currency),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: dir == 'lent'
                                    ? colors.income
                                    : colors.expense,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final d in debts.where((d) {
                      final isDone =
                          d.text('status') == 'completed' ||
                          d.text('status') == 'paid' ||
                          d.text('status') == 'cancelled';
                      if (isCompleted) return isDone;
                      return !isDone && d.text('direction') == dir;
                    })) ...[
                      _DebtCard(
                        debt: d,
                        payments: payments,
                        people: people,
                        onTap: () => showDebtDetail(context, d),
                      ),
                    ],
                  ],
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Record debt;
  final List<Record> payments;
  final List<Record> people;
  final VoidCallback onTap;

  const _DebtCard({
    required this.debt,
    required this.payments,
    required this.people,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final personName =
        people
            .where((p) => p.id == debt.text('person_id'))
            .firstOrNull
            ?.text('name') ??
        'Người liên quan';
    final isLent = debt.text('direction') == 'lent';
    final remaining = Ledger.remaining(debt, payments);
    final isCompleted = debt.text('status') == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isLent ? colors.income : colors.expense).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isLent ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isLent ? colors.income : colors.expense,
            size: 20,
          ),
        ),
        title: Text(
          personName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          isCompleted
              ? 'Đã hoàn tất thủ công'
              : (debt.data['due_at'] == null
                    ? (isLent ? 'Cho vay' : 'Vay nợ')
                    : 'Hạn: ${context.dateLabel(debt.date('due_at'))}'),
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${remaining < 0 ? '−' : ''}${Money.format(remaining.abs(), debt.text('currency'))}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? colors.textMuted
                    : (remaining < 0
                          ? colors.warning
                          : (isLent ? colors.income : colors.expense)),
              ),
            ),
            Text(
              'Gốc: ${Money.format(debt.money('principal_amount'), debt.text('currency'))}',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

Future<void> showDebtForm(
  BuildContext context, {
  Record? debt,
  bool edit = false,
}) => showDialog<void>(
  context: context,
  builder: (_) => DebtForm(debt: debt, edit: edit),
);

class DebtForm extends ConsumerStatefulWidget {
  final Record? debt;
  final bool edit;
  const DebtForm({super.key, this.debt, this.edit = false});
  @override
  ConsumerState<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<DebtForm> {
  final amount = TextEditingController(), note = TextEditingController();
  String? person, account, error;
  DebtDirection direction = DebtDirection.lent;
  bool busy = false, initialized = false;
  DateTime? due;
  DateTime occurred = DateTime.now();
  bool get principalForm => widget.debt == null || widget.edit;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (widget.edit && d != null) {
      amount.text = Money.groupedInput(
        d.money('principal_amount'),
        d.text('currency'),
      );
      note.text = d.text('note');
      occurred = d.date('started_at');
      person = d.text('person_id');
      direction = DebtDirection.values.byName(d.text('direction'));
      if (d.data['due_at'] != null) due = d.date('due_at');
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save(List<Record> people, List<Record> accounts) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await saveAndSync(ref, (repo) async {
        final service = DebtService(repo),
            cash = accounts.where((a) => a.id == account).firstOrNull;
        final String currency =
            widget.debt?.text('currency') ?? cash?.text('currency') ?? 'VND';
        final value = Money.parse(amount.text, currency: currency);
        if (widget.edit) {
          final p = people.where((p) => p.id == person).firstOrNull;
          if (p == null) {
            throw const FormatException('Create or select a person first');
          }
          await service.updateDebt(
            widget.debt!,
            person: p,
            direction: direction,
            amount: value,
            account: cash,
            due: due,
            note: note.text,
            startedAt: occurred,
          );
        } else if (widget.debt != null) {
          await service.repay(
            widget.debt!,
            value,
            account: cash,
            paidAt: occurred,
            note: note.text,
          );
        } else {
          final p = people.where((p) => p.id == person).firstOrNull;
          if (p == null) {
            throw const FormatException('Create or select a person first');
          }
          await service.createDebt(
            person: p,
            direction: direction,
            amount: value,
            currency: currency,
            account: cash,
            due: due,
            startedAt: occurred,
            note: note.text,
          );
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(recordsProvider(Entity.people)).value ?? [],
        accounts = (ref.watch(recordsProvider(Entity.accounts)).value ?? [])
            .where((a) => !a.flag('is_archived') || widget.edit)
            .toList();

    final movements =
        ref.watch(recordsProvider(Entity.transactions)).value ?? <Record>[];
    final original = movements
        .where((t) => t.id == widget.debt?.text('linked_transaction_id'))
        .firstOrNull;
    if (widget.edit && !initialized && original != null) {
      account = original.data['account_id'];
      initialized = true;
    }
    final bankReadOnly = widget.edit && original?.data['bank_source'] != null;
    final hasPayments =
        (ref.watch(recordsProvider(Entity.debtPayments)).value ?? <Record>[])
            .any((p) => p.text('debt_id') == widget.debt?.id);
    return FormDialog(
      title: widget.edit
          ? 'Chỉnh sửa công nợ'
          : widget.debt == null
          ? (direction == DebtDirection.lent
                ? 'Tạo khoản cho vay'
                : 'Tạo khoản vay nợ')
          : (widget.debt!.text('direction') == 'lent'
                ? 'Ghi nhận thu nợ'
                : 'Ghi nhận trả nợ'),
      busy: busy,
      error: error,
      save: () => save(people, accounts),
      children: [
        if (principalForm)
          DropdownButtonFormField<DebtDirection>(
            initialValue: direction,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại công nợ'),
            items: const [
              DropdownMenuItem(
                value: DebtDirection.lent,
                child: Text('Cho vay'),
              ),
              DropdownMenuItem(
                value: DebtDirection.borrowed,
                child: Text('Vay nợ'),
              ),
            ],
            onChanged: bankReadOnly || hasPayments
                ? null
                : (v) => setState(() => direction = v!),
          ),
        if (principalForm)
          PersonPicker(
            label: context.tr('Người liên quan'),
            value: person,
            records: people,
            onChanged: (v) => setState(() => person = v),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(principalForm ? 'Ngày giao dịch' : 'Ngày thu/trả nợ'),
          subtitle: Text(context.dateLabel(occurred)),
          trailing: const Icon(Icons.calendar_today),
          onTap: bankReadOnly
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: occurred,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(
                      () => occurred = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        occurred.hour,
                        occurred.minute,
                        occurred.second,
                        occurred.millisecond,
                        occurred.microsecond,
                      ),
                    );
                  }
                },
        ),
        TextField(
          controller: amount,
          readOnly: bankReadOnly,
          inputFormatters: [MoneyInputFormatter(allowNegative: false)],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: principalForm ? 'Số tiền gốc' : 'Số tiền trả',
            suffixText: accounts.firstOrNull?.text('currency') ?? 'VND',
          ),
          autofocus: true,
        ),
        RecordPicker(
          label: 'Tài khoản thanh toán',
          value: account,
          records: accounts,
          onChanged: bankReadOnly ? null : (v) => setState(() => account = v),
          optional: true,
        ),
        if (principalForm)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hạn trả (tuỳ chọn)'),
            subtitle: Text(
              due == null ? 'Không có hạn' : context.dateLabel(due!),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate:
                    due ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => due = d);
            },
          ),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
        ),
      ],
    );
  }
}

Future<void> showDebtDetail(BuildContext context, Record debt) =>
    showDialog<void>(
      context: context,
      builder: (_) => DebtDetail(debt: debt),
    );

class DebtDetail extends ConsumerWidget {
  final Record debt;
  const DebtDetail({super.key, required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debt =
        (ref.watch(recordsProvider(Entity.debts)).value ?? <Record>[])
            .where((d) => d.id == this.debt.id)
            .firstOrNull ??
        this.debt;
    final payments =
        (ref.watch(recordsProvider(Entity.debtPayments)).value ?? [])
            .where((p) => p.text('debt_id') == debt.id)
            .toList()
          ..sort((a, b) => b.text('paid_at').compareTo(a.text('paid_at')));
    final left = Ledger.remaining(debt, payments);
    final isCompleted = debt.text('status') == 'completed';
    final colors = context.colors;

    return AlertDialog(
      title: Text(
        debt.text('direction') == 'lent' ? 'Khoản cho vay' : 'Khoản vay nợ',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${left < 0 ? '−' : ''}${Money.format(left.abs(), debt.text('currency'))}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? colors.textMuted
                      : (left < 0
                            ? colors.warning
                            : (debt.text('direction') == 'lent'
                                  ? colors.income
                                  : colors.expense)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ngày giao dịch: ${context.dateLabel(debt.date('started_at'))}',
              ),
              Text(
                'Còn lại · Gốc: ${Money.format(debt.money('principal_amount'), debt.text('currency'))}',
                style: TextStyle(color: colors.textSecondary),
              ),
              if (isCompleted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ĐÃ HOÀN TẤT THỦ CÔNG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (debt.text('note').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(debt.text('note')),
              ],
              const Divider(height: 24),
              Text(
                'LỊCH SỬ THU/TRẢ NỢ (${payments.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              for (final p in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    Money.format(p.money('amount'), debt.text('currency')),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${context.dateLabel(p.date('paid_at'))} ${p.text('note')}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Xóa lần thu/trả nợ này',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirmDelete(context)) {
                        try {
                          await saveAndSync(
                            ref,
                            (r) => DebtService(r).removePayment(p),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            message(context, userError(context, e));
                          }
                        }
                      }
                    },
                  ),
                ),
              if (payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có lần thu/trả nợ nào.'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        TextButton.icon(
          onPressed: () => showDebtForm(context, debt: debt, edit: true),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Chỉnh sửa'),
        ),
        if (!isCompleted && debt.text('status') != 'cancelled') ...[
          OutlinedButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Hoàn tất khoản nợ?'),
                  content: const Text(
                    'Khoản nợ sẽ được chuyển vào nhóm Đã hoàn tất, giữ nguyên lịch sử và không tạo thêm giao dịch cân bằng.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Hoàn tất'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await saveAndSync(
                    ref,
                    (r) => DebtService(r).markDebtCompleted(debt),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) message(context, userError(context, e));
                }
              }
            },
            child: const Text('Hoàn tất'),
          ),
          FilledButton(
            onPressed: () => showDebtForm(context, debt: debt),
            child: Text(debt.text('direction') == 'lent' ? 'Thu nợ' : 'Trả nợ'),
          ),
        ],
      ],
    );
  }
}

Future<void> showPersonDetail(BuildContext context, Record person) =>
    showDialog<void>(
      context: context,
      builder: (_) => PersonDetail(person: person),
    );

class PersonDetail extends ConsumerWidget {
  final Record person;
  const PersonDetail({super.key, required this.person});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = (ref.watch(recordsProvider(Entity.debts)).value ?? [])
            .where((d) => d.text('person_id') == person.id)
            .toList(),
        payments = ref.watch(recordsProvider(Entity.debtPayments)).value ?? [],
        notes = (ref.watch(recordsProvider(Entity.notes)).value ?? []).where(
          (n) => n.text('person_id') == person.id,
        );
    return AlertDialog(
      title: Text(person.text('name')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.text('phone_optional')),
              Text(person.text('note')),
              const Divider(),
              for (final d in debts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    d.text('direction') == 'lent'
                        ? context.tr('They owe me')
                        : context.tr('I owe them'),
                  ),
                  subtitle: Text(context.tr(Ledger.debtStatus(d, payments))),
                  trailing: Text(
                    Money.format(
                      Ledger.remaining(d, payments),
                      d.text('currency'),
                    ),
                  ),
                  onTap: () => showDebtDetail(context, d),
                ),
              if (debts.isEmpty) Text(context.tr('No related debts.')),
              const Divider(),
              Text(context.tr('Related notes')),
              for (final n in notes)
                ListTile(
                  title: Text(n.text('title')),
                  subtitle: Text(n.text('content')),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Close')),
        ),
        FilledButton(
          onPressed: () =>
              showCatalogForm(context, Entity.people, record: person),
          child: Text(context.tr('Edit person')),
        ),
      ],
    );
  }
}
