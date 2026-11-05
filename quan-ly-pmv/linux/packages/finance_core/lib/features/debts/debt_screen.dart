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
        // ── Top Bar / Action Header ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Công nợ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quản lý cho vay và vay nợ cá nhân',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDebtForm(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tạo khoản nợ'),
              ),
            ],
          ),
        ),

        // ── Danh sách công nợ ──────────────────────────────────────────────
        Expanded(
          child: AsyncRecords(
            value: ref.watch(recordsProvider(Entity.debts)),
            builder: (debts) {
              if (debts.isEmpty) {
                return EmptyState(
                  title: 'Chưa có khoản công nợ nào',
                  description:
                      'Ghi lại các khoản cho vay hoặc vay nợ, sau đó thêm các lần thu/trả nợ.',
                  icon: Icons.handshake_outlined,
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  for (final (title, dir, isCompleted) in sections) ...[
                    // Section title row
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: colors.textSecondary,
                            ),
                          ),
                          if (!isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (dir == 'lent'
                                            ? colors.income
                                            : colors.expense)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                Money.format(outstanding(dir), currency),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: dir == 'lent'
                                      ? colors.income
                                      : colors.expense,
                                ),
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
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DebtCard
// ─────────────────────────────────────────────────────────────────────────────

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

    final directionColor = isLent ? colors.income : colors.expense;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.bgElevated
                      : directionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_outline_rounded
                      : isLent
                      ? Icons.south_rounded
                      : Icons.north_rounded,
                  color: isCompleted ? colors.textMuted : directionColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title and dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      children: [
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.bgElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Đã hoàn tất',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        else
                          Text(
                            debt.data['due_at'] == null
                                ? 'Giao dịch: ${context.dateLabel(debt.date('started_at'))}'
                                : 'Hạn: ${context.dateLabel(debt.date('due_at'))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Remaining & Principal
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${remaining < 0 ? '−' : ''}${Money.format(remaining.abs(), debt.text('currency'))}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isCompleted
                          ? colors.textMuted
                          : (remaining < 0 ? colors.warning : directionColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gốc: ${Money.format(debt.money('principal_amount'), debt.text('currency'))}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textSecondary,
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
// DebtForm (Create / Edit / Repay)
// ─────────────────────────────────────────────────────────────────────────────

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
            throw const FormatException(
              'Vui lòng chọn hoặc tạo người liên quan.',
            );
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
            throw const FormatException(
              'Vui lòng chọn hoặc tạo người liên quan.',
            );
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
    final colors = context.colors;
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

    final currency =
        widget.debt?.text('currency') ??
        accounts.firstOrNull?.text('currency') ??
        'VND';

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
        // ── Loại công nợ (Cho vay / Vay nợ) ────────────────────────────────
        if (principalForm) ...[
          Container(
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _DebtTypeButton(
                    label: 'Cho vay',
                    icon: Icons.south_rounded,
                    selected: direction == DebtDirection.lent,
                    activeColor: colors.income,
                    enabled: !(bankReadOnly || hasPayments),
                    onTap: () => setState(() => direction = DebtDirection.lent),
                  ),
                ),
                Expanded(
                  child: _DebtTypeButton(
                    label: 'Vay nợ',
                    icon: Icons.north_rounded,
                    selected: direction == DebtDirection.borrowed,
                    activeColor: colors.expense,
                    enabled: !(bankReadOnly || hasPayments),
                    onTap: () =>
                        setState(() => direction = DebtDirection.borrowed),
                  ),
                ),
              ],
            ),
          ),
          PersonPicker(
            label: context.tr('Người liên quan'),
            value: person,
            records: people,
            onChanged: (v) => setState(() => person = v),
          ),
        ],

        // ── Số tiền ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                principalForm ? 'Số tiền gốc' : 'Số tiền thu/trả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: principalForm ? 'Số tiền gốc' : 'Số tiền trả',
                      child: TextField(
                        key: const ValueKey('debt-amount'),
                        controller: amount,
                        readOnly: bankReadOnly,
                        inputFormatters: [
                          MoneyInputFormatter(allowNegative: false),
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: direction == DebtDirection.lent
                              ? colors.income
                              : colors.expense,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        autofocus: true,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currency,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Ngày giao dịch / Ngày thu/trả nợ ───────────────────────────────
        InkWell(
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: colors.primaryAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        principalForm ? 'Ngày giao dịch' : 'Ngày thu/trả nợ',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        context.dateLabel(occurred),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!bankReadOnly)
                  Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
              ],
            ),
          ),
        ),

        // ── Tài khoản thanh toán (Tuỳ chọn) ────────────────────────────────
        RecordPicker(
          label: 'Tài khoản thanh toán (tuỳ chọn)',
          value: account,
          records: accounts,
          onChanged: bankReadOnly ? null : (v) => setState(() => account = v),
          optional: true,
        ),

        // ── Hạn trả (Tuỳ chọn - chỉ cho principalForm) ─────────────────────
        if (principalForm)
          InkWell(
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hạn trả (tuỳ chọn)',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          due == null
                              ? 'Không có hạn trả'
                              : context.dateLabel(due!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: due == null
                                ? colors.textMuted
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (due != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => due = null),
                      tooltip: 'Xoá hạn trả',
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.textMuted,
                    ),
                ],
              ),
            ),
          ),

        // ── Ghi chú ────────────────────────────────────────────────────────
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (tuỳ chọn)',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DebtTypeButton
// ─────────────────────────────────────────────────────────────────────────────

class _DebtTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final bool enabled;
  final VoidCallback onTap;

  const _DebtTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? (isDark
                  ? activeColor.withValues(alpha: 0.25)
                  : activeColor.withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: enabled
                      ? (selected ? activeColor : colors.textMuted)
                      : colors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: enabled
                        ? (selected ? activeColor : colors.textSecondary)
                        : colors.textMuted.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DebtDetail
// ─────────────────────────────────────────────────────────────────────────────

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
    final isLent = debt.text('direction') == 'lent';
    final colors = context.colors;

    final directionColor = isLent ? colors.income : colors.expense;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: directionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLent ? Icons.south_rounded : Icons.north_rounded,
              color: directionColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLent ? 'Khoản cho vay' : 'Khoản vay nợ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remaining balance box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.bgElevated
                      : directionColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCompleted
                        ? colors.borderSubtle
                        : directionColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CÒN LẠI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${left < 0 ? '−' : ''}${Money.format(left.abs(), debt.text('currency'))}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isCompleted
                            ? colors.textMuted
                            : (left < 0 ? colors.warning : directionColor),
                      ),
                    ),
                    if (left < 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Đã trả vượt số tiền gốc',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details
              _DebtInfoRow(
                label: 'Ngày giao dịch',
                value: context.dateLabel(debt.date('started_at')),
              ),
              _DebtInfoRow(
                label: 'Tiền gốc',
                value: Money.format(
                  debt.money('principal_amount'),
                  debt.text('currency'),
                ),
              ),
              if (debt.data['due_at'] != null)
                _DebtInfoRow(
                  label: 'Hạn trả',
                  value: context.dateLabel(debt.date('due_at')),
                ),
              if (debt.text('note').isNotEmpty)
                _DebtInfoRow(label: 'Ghi chú', value: debt.text('note')),

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đã hoàn tất thủ công',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 28),

              // Payment history
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LỊCH SỬ THU/TRẢ NỢ (${payments.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Chưa có lần thu/trả nợ nào.',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                for (final p in payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Money.format(
                                    p.money('amount'),
                                    debt.text('currency'),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${context.dateLabel(p.date('paid_at'))}${p.text('note').isNotEmpty ? ' · ${p.text('note')}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Xóa lần thu/trả nợ này',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: colors.expense,
                            ),
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
                        ],
                      ),
                    ),
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
          icon: const Icon(Icons.edit_outlined, size: 18),
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
          FilledButton.icon(
            onPressed: () => showDebtForm(context, debt: debt),
            icon: Icon(
              isLent ? Icons.south_rounded : Icons.north_rounded,
              size: 18,
            ),
            label: Text(isLent ? 'Thu nợ' : 'Trả nợ'),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DebtInfoRow
// ─────────────────────────────────────────────────────────────────────────────

class _DebtInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebtInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PersonDetail
// ─────────────────────────────────────────────────────────────────────────────

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
    final colors = context.colors;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primaryAccent.withValues(alpha: 0.12),
            child: Icon(
              Icons.person_outline_rounded,
              color: colors.primaryAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.text('name'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (person.text('phone_optional').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        person.text('phone_optional'),
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (person.text('note').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    person.text('note'),
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ),
              const Divider(height: 24),
              Text(
                'Khoản nợ liên quan (${debts.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final d in debts)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(
                      d.text('direction') == 'lent' ? 'Cho vay' : 'Vay nợ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      context.tr(Ledger.debtStatus(d, payments)),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      Money.format(
                        Ledger.remaining(d, payments),
                        d.text('currency'),
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: d.text('direction') == 'lent'
                            ? colors.income
                            : colors.expense,
                      ),
                    ),
                    onTap: () => showDebtDetail(context, d),
                  ),
                ),
              if (debts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.tr('Không có khoản công nợ nào.'),
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ),
              const Divider(height: 24),
              Text(
                'Ghi chú liên quan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.text('title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (n.text('content').isNotEmpty)
                          Text(
                            n.text('content'),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Không có ghi chú liên quan.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
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
        FilledButton.icon(
          onPressed: () =>
              showCatalogForm(context, Entity.people, record: person),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.tr('Sửa người liên quan')),
        ),
      ],
    );
  }
}
