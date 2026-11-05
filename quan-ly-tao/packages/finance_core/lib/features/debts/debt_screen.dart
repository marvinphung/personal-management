import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
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
            ref.watch(recordsProvider(Entity.debtPayments)).value ?? [],
        people = ref.watch(recordsProvider(Entity.people)).value ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Keep promises clear'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDebtForm(context),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Debt')),
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
                  title: context.tr('No debts to track'),
                  description: context.tr(
                    'Record money you lend or borrow, then add repayments.',
                  ),
                  onAdd: () => showDebtForm(context),
                );
              }
              int outstanding(String direction) => debts
                  .where(
                    (d) =>
                        d.text('currency') == currency &&
                        d.text('direction') == direction &&
                        d.text('status') != 'cancelled',
                  )
                  .fold(0, (sum, d) => sum + Ledger.remaining(d, payments));
              return ListView(
                children: [
                  for (final section in [
                    'People owe me',
                    'I owe',
                    'Settled',
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        section == 'Settled'
                            ? context.tr(section)
                            : '${context.tr(section)} · ${Money.format(outstanding(section == "People owe me" ? "lent" : "borrowed"), currency)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final d in debts.where((d) {
                      final status = Ledger.debtStatus(d, payments),
                          settled = status == 'paid' || status == 'cancelled';
                      return section == 'Settled'
                          ? settled
                          : !settled &&
                                (section == 'People owe me'
                                    ? d.text('direction') == 'lent'
                                    : d.text('direction') == 'borrowed');
                    }))
                      ListTile(
                        leading: Icon(
                          d.text('direction') == 'lent'
                              ? Icons.call_received
                              : Icons.call_made,
                        ),
                        title: Text(
                          people
                                  .where((p) => p.id == d.text('person_id'))
                                  .firstOrNull
                                  ?.text('name') ??
                              context.tr('Person'),
                        ),
                        subtitle: Text(
                          '${context.tr(Ledger.debtStatus(d, payments))} · ${d.data['due_at'] == null ? context.tr('No due date') : context.tr('Due {date}', {'date': context.dateLabel(d.date('due_at'))})}',
                        ),
                        trailing: Text(
                          Money.format(
                            Ledger.remaining(d, payments),
                            d.text('currency'),
                          ),
                        ),
                        onTap: () => showDebtDetail(context, d),
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
}

Future<void> showDebtForm(BuildContext context, {Record? debt}) =>
    showDialog<void>(
      context: context,
      builder: (_) => DebtForm(debt: debt),
    );

class DebtForm extends ConsumerStatefulWidget {
  final Record? debt;
  const DebtForm({super.key, this.debt});
  @override
  ConsumerState<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<DebtForm> {
  final amount = TextEditingController(), note = TextEditingController();
  String? person, account, error;
  DebtDirection direction = DebtDirection.lent;
  bool busy = false;
  DateTime? due;
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
            widget.debt?.text('currency') ??
            cash?.text('currency') ??
            ref.read(currencyProvider);
        final value = Money.parse(amount.text, currency: currency);
        if (widget.debt != null) {
          await service.repay(
            widget.debt!,
            value,
            account: cash,
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
            .where(
              (a) =>
                  !a.flag('is_archived') &&
                  (widget.debt == null ||
                      a.text('currency') == widget.debt!.text('currency')),
            )
            .toList();
    return FormDialog(
      title: widget.debt == null
          ? context.tr('Record a debt')
          : context.tr('Record repayment'),
      busy: busy,
      error: error,
      save: () => save(people, accounts),
      children: [
        TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.tr('Amount'),
            hintText: '1m',
          ),
        ),
        if (widget.debt == null) ...[
          SegmentedButton<DebtDirection>(
            segments: [
              ButtonSegment(
                value: DebtDirection.lent,
                label: Text(context.tr('I lent')),
              ),
              ButtonSegment(
                value: DebtDirection.borrowed,
                label: Text(context.tr('I borrowed')),
              ),
            ],
            selected: {direction},
            onSelectionChanged: (v) => setState(() => direction = v.first),
          ),
          RecordPicker(
            label: context.tr('Person'),
            value: person,
            records: people,
            onChanged: (v) => setState(() => person = v),
          ),
          TextButton.icon(
            onPressed: () => showCatalogForm(context, Entity.people),
            icon: const Icon(Icons.person_add_alt),
            label: Text(context.tr('Add person')),
          ),
        ],
        RecordPicker(
          label: context.tr('Cash account (optional)'),
          value: account,
          records: accounts,
          onChanged: (v) => setState(() => account = v),
          optional: true,
        ),
        Text(
          context.tr(
            'Choosing an account also records the cash movement. Debt principal is excluded from normal income and spending.',
          ),
        ),
        if (widget.debt == null)
          TextButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(
              due == null
                  ? context.tr('Set due date')
                  : context.tr('Due {date}', {'date': context.dateLabel(due!)}),
            ),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => due = d);
            },
          ),
        TextField(
          controller: note,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: context.tr('Note')),
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
    final payments =
        (ref.watch(recordsProvider(Entity.debtPayments)).value ?? [])
            .where((p) => p.text('debt_id') == debt.id)
            .toList()
          ..sort((a, b) => b.text('paid_at').compareTo(a.text('paid_at')));
    final left = Ledger.remaining(debt, payments);
    return AlertDialog(
      title: Text(
        debt.text('direction') == 'lent'
            ? context.tr('Money lent')
            : context.tr('Money borrowed'),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Money.format(left, debt.text('currency')),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                context.tr('Remaining · Principal {amount}', {
                  'amount': Money.format(
                    debt.money('principal_amount'),
                    debt.text('currency'),
                  ),
                }),
              ),
              const SizedBox(height: 16),
              Text(debt.text('note')),
              const Divider(),
              Text(context.tr('Repayments')),
              for (final p in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    Money.format(p.money('amount'), debt.text('currency')),
                  ),
                  subtitle: Text(
                    '${context.dateLabel(p.date('paid_at'))} ${p.text('note')}',
                  ),
                  trailing: IconButton(
                    tooltip: context.tr(
                      'Delete repayment and linked cash movement',
                    ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(context.tr('No repayments yet.')),
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
        if (left > 0 && debt.text('status') != 'cancelled')
          FilledButton(
            onPressed: () => showDebtForm(context, debt: debt),
            child: Text(context.tr('Add repayment')),
          ),
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
