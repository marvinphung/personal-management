import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import '../../core/utils/ledger.dart';
import '../debts/debt_screen.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  final Entity entity;
  const CatalogScreen({super.key, required this.entity});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(balanceProvider).value ?? {};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.tr('Search names'),
                  ),
                  onChanged: (v) => setState(() => query = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => showCatalogForm(context, widget.entity),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add')),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncRecords(
            value: ref.watch(recordsProvider(widget.entity)),
            builder: (records) {
              final filtered =
                  records
                      .where(
                        (r) => r.text('name').toLowerCase().contains(query),
                      )
                      .toList()
                    ..sort((a, b) => a.text('name').compareTo(b.text('name')));
              if (filtered.isEmpty) {
                return EmptyState(
                  title: context.tr('No {entity} yet', {
                    'entity': context.tr(widget.entity.name),
                  }),
                  description: context.tr(
                    'Add a record to organize your finances.',
                  ),
                  onAdd: () => showCatalogForm(context, widget.entity),
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  return ListTile(
                    leading: Icon(
                      widget.entity == Entity.accounts
                          ? Icons.account_balance_wallet_outlined
                          : widget.entity == Entity.people
                          ? Icons.person_outline
                          : Icons.label_outline,
                    ),
                    title: Text(
                      '${r.text('name')}${r.flag('is_archived') ? context.tr(' · Archived') : ''}',
                    ),
                    subtitle: widget.entity == Entity.accounts
                        ? Text(
                            Money.format(
                              balances[r.id] ?? 0,
                              r.text('currency'),
                            ),
                          )
                        : Text(
                            r.text('type').isNotEmpty
                                ? context.tr(r.text('type'))
                                : r.text('note'),
                          ),
                    onTap: () => widget.entity == Entity.people
                        ? showPersonDetail(context, r)
                        : widget.entity == Entity.accounts
                        ? showAccountDetail(
                            context,
                            ref,
                            r,
                            balances[r.id] ?? 0,
                          )
                        : showCatalogForm(context, widget.entity, record: r),
                    trailing: IconButton(
                      tooltip: context.tr('Edit'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          showCatalogForm(context, widget.entity, record: r),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> showCatalogForm(
  BuildContext context,
  Entity entity, {
  Record? record,
}) => showDialog<void>(
  context: context,
  builder: (_) => CatalogForm(entity: entity, record: record),
);

class CatalogForm extends ConsumerStatefulWidget {
  final Entity entity;
  final Record? record;
  const CatalogForm({super.key, required this.entity, this.record});
  @override
  ConsumerState<CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends ConsumerState<CatalogForm> {
  final name = TextEditingController(),
      opening = TextEditingController(),
      note = TextEditingController(),
      phone = TextEditingController();
  String type = '', currency = 'VND';
  bool archived = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    name.text = r?.text('name') ?? '';
    type =
        r?.text('type') ??
        (widget.entity == Entity.accounts ? 'cash' : 'expense');
    currency = r?.text('currency') ?? 'VND';
    opening.text = Money.input(r?.money('opening_balance') ?? 0, currency);
    note.text = r?.text('note') ?? '';
    phone.text = r?.text('phone_optional') ?? '';
    archived = r?.flag('is_archived') ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    note.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await saveAndSync(ref, (repo) async {
        final data = <String, dynamic>{'name': name.text.trim()};
        if (widget.entity == Entity.accounts) {
          final value = Money.parseBalance(opening.text, currency: currency);
          data.addAll({
            'type': type,
            'currency': currency,
            'opening_balance': value,
            if (widget.record != null &&
                widget.record!.text('currency') != currency) ...{
              'bank_balance': null,
              'bank_balance_at': null,
            },
            'is_archived': archived,
          });
        }
        if (widget.entity == Entity.categories) {
          data.addAll({'type': type, 'is_archived': archived});
        }
        if (widget.entity == Entity.tags) {
          data['name'] = name.text.trim().replaceFirst('#', '').toLowerCase();
        }
        if (widget.entity == Entity.people) {
          data.addAll({
            'note': note.text,
            'phone_optional': phone.text.trim().isEmpty
                ? null
                : phone.text.trim(),
          });
        }
        await repo.save(
          widget.record?.patch(data) ?? repo.create(widget.entity, data),
        );
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: context.tr('{action} {entity}', {
      'action': context.tr(widget.record == null ? 'Add' : 'Edit'),
      'entity': context.tr(widget.entity.name),
    }),
    busy: busy,
    error: error,
    save: save,
    children: [
      TextField(
        controller: name,
        autofocus: true,
        decoration: InputDecoration(labelText: context.tr('Name')),
      ),
      if ([Entity.accounts, Entity.categories].contains(widget.entity))
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: InputDecoration(labelText: context.tr('Type')),
          items:
              (widget.entity == Entity.accounts
                      ? ['cash', 'bank', 'e_wallet', 'savings', 'other']
                      : ['expense', 'income', 'both'])
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text(context.tr(v))),
                  )
                  .toList(),
          onChanged: (v) => setState(() => type = v!),
        ),
      if (widget.entity == Entity.accounts) ...[
        DropdownButtonFormField<String>(
          initialValue: currency,
          decoration: InputDecoration(labelText: context.tr('Currency')),
          items: Money.exponents.keys
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: widget.record == null
              ? (v) => setState(() => currency = v!)
              : null,
        ),
        TextField(
          controller: opening,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(labelText: context.tr('Opening balance')),
        ),
      ],
      if (widget.entity == Entity.people) ...[
        TextField(
          controller: phone,
          decoration: InputDecoration(
            labelText: context.tr('Phone (optional)'),
          ),
        ),
        TextField(
          controller: note,
          decoration: InputDecoration(labelText: context.tr('Note')),
          maxLines: 3,
        ),
      ],
      if ([Entity.accounts, Entity.categories].contains(widget.entity))
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Archived')),
          value: archived,
          onChanged: (v) => setState(() => archived = v),
        ),
      if (widget.record != null &&
          [Entity.tags, Entity.people].contains(widget.entity))
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (await confirmDelete(context)) {
                    try {
                      await saveAndSync(ref, (r) => r.remove(widget.record!));
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        setState(() => error = userError(context, e));
                      }
                    }
                  }
                },
          child: Text(context.tr('Delete')),
        ),
    ],
  );
}

Future<void> showAccountDetail(
  BuildContext context,
  WidgetRef ref,
  Record account,
  int balance,
) async {
  final workspace = await ref.read(workspaceProvider.future);
  if (workspace == null || !context.mounted) return;
  final recent = await workspace.repository.accountTransactions(account.id);
  final period = await workspace.repository.accountTransactions(
    account.id,
    month: ref.read(monthProvider),
    limit: 10000,
  );
  final totals = Ledger.monthly(
    period,
    ref.read(monthProvider),
    account.text('currency'),
  );
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(account.text('name')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Money.format(balance, account.text('currency')),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (account.data['bank_balance_at'] != null)
                Text(
                  context.tr('Bank balance at {date}: {amount}', {
                    'date': context.dateLabel(
                      account.date('bank_balance_at'),
                      time: true,
                    ),
                    'amount': Money.format(
                      account.money('bank_balance'),
                      account.text('currency'),
                    ),
                  }),
                ),
              const SizedBox(height: 20),
              Text(
                context.tr('Selected month income: {amount}', {
                  'amount': Money.format(
                    totals.income,
                    account.text('currency'),
                  ),
                }),
              ),
              Text(
                context.tr('Selected month expense: {amount}', {
                  'amount': Money.format(
                    totals.expense,
                    account.text('currency'),
                  ),
                }),
              ),
              const SizedBox(height: 16),
              Text(context.tr('Recent transactions')),
              for (final t in recent)
                ListTile(
                  title: Text(t.text('description')),
                  subtitle: Text(context.tr(t.text('type'))),
                  trailing: Text(
                    Money.format(t.money('amount'), t.text('currency')),
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
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            showCatalogForm(context, Entity.accounts, record: account);
          },
          child: Text(context.tr('Edit account')),
        ),
      ],
    ),
  );
}
