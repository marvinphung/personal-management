import '../../core/utils/money_input_formatter.dart';
import '../../core/utils/tag_display.dart';
import '../../core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/components.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';
import '../../core/utils/ledger.dart';
import '../debts/debt_screen.dart';
import '../../core/utils/tag_name.dart';

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
    final colors = context.colors;
    final balances = ref.watch(balanceProvider).value ?? {};
    final categories = widget.entity == Entity.tags
        ? ref.watch(recordsProvider(Entity.categories)).value ?? <Record>[]
        : <Record>[];

    final entityLabel = switch (widget.entity) {
      Entity.accounts => 'Tài khoản',
      Entity.categories => 'Danh mục',
      Entity.tags => 'Thẻ (Tags)',
      Entity.people => 'Người liên quan',
      _ => context.tr(widget.entity.name),
    };

    return Scaffold(
      appBar: AppBar(title: Text(entityLabel)),
      body: Column(
        children: [
          // ── Search & Add Row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: colors.textMuted),
                      hintText: 'Tìm kiếm $entityLabel…',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => setState(() => query = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => showCatalogForm(context, widget.entity),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Thêm'),
                ),
              ],
            ),
          ),

          // ── Records List ─────────────────────────────────────────────────
          Expanded(
            child: AsyncRecords(
              value: ref.watch(recordsProvider(widget.entity)),
              builder: (records) {
                final filtered =
                    records
                        .where(
                          (r) =>
                              (widget.entity == Entity.tags
                                      ? TagDisplay.forRecord(r)
                                      : r.text('name'))
                                  .toLowerCase()
                                  .contains(query),
                        )
                        .toList()
                      ..sort(
                        (a, b) =>
                            (widget.entity == Entity.tags
                                    ? TagDisplay.forRecord(a)
                                    : a.text('name'))
                                .compareTo(
                                  widget.entity == Entity.tags
                                      ? TagDisplay.forRecord(b)
                                      : b.text('name'),
                                ),
                      );
                if (filtered.isEmpty) {
                  return EmptyState(
                    title: 'Chưa có $entityLabel nào',
                    description:
                        'Thêm mục mới để quản lý dữ liệu tài chính của bạn.',
                    icon: switch (widget.entity) {
                      Entity.accounts => Icons.account_balance_wallet_outlined,
                      Entity.people => Icons.people_outline_rounded,
                      Entity.tags => Icons.label_outline_rounded,
                      _ => Icons.category_outlined,
                    },
                    onAdd: () => showCatalogForm(context, widget.entity),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final isArchived = r.flag('is_archived');
                    final iconData = switch (widget.entity) {
                      Entity.accounts => Icons.account_balance_wallet_outlined,
                      Entity.people => Icons.person_outline_rounded,
                      Entity.tags => Icons.tag_rounded,
                      _ => Icons.category_outlined,
                    };

                    final displayName = widget.entity == Entity.tags
                        ? '#${TagDisplay.forRecord(r)}'
                        : r.text('name');

                    final subtitleText = widget.entity == Entity.accounts
                        ? r.text('currency')
                        : widget.entity == Entity.tags
                        ? (categories
                                  .where((c) => c.id == r.text('category_id'))
                                  .firstOrNull
                                  ?.text('name') ??
                              'Chưa gắn danh mục')
                        : widget.entity == Entity.people
                        ? (r.text('phone_optional').isNotEmpty
                              ? r.text('phone_optional')
                              : r.text('note'))
                        : (r.text('type') == 'expense'
                              ? 'Chi tiêu'
                              : r.text('type') == 'income'
                              ? 'Thu nhập'
                              : 'Cả hai');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.bgElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            iconData,
                            size: 20,
                            color: isArchived
                                ? colors.textMuted
                                : colors.primaryAccent,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isArchived
                                      ? colors.textMuted
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            if (isArchived)
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
                                  'Đã lưu trữ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: subtitleText.isNotEmpty
                            ? Text(
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              )
                            : null,
                        trailing: widget.entity == Entity.accounts
                            ? Text(
                                Money.format(
                                  balances[r.id] ?? 0,
                                  r.text('currency'),
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: colors.textPrimary,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Chỉnh sửa',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: colors.textMuted,
                                ),
                                onPressed: () => showCatalogForm(
                                  context,
                                  widget.entity,
                                  record: r,
                                ),
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
                            : showCatalogForm(
                                context,
                                widget.entity,
                                record: r,
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CatalogForm
// ─────────────────────────────────────────────────────────────────────────────

Future<Record?> showCatalogForm(
  BuildContext context,
  Entity entity, {
  Record? record,
}) => showDialog<Record>(
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
  String? error, category;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    name.text =
        widget.entity == Entity.tags &&
            r != null &&
            r.text('display_name').isNotEmpty
        ? TagDisplay.forRecord(r)
        : r?.text('name') ?? '';
    category = r?.data['category_id'] as String?;
    type =
        r?.text('type') ??
        (widget.entity == Entity.accounts ? 'cash' : 'expense');
    currency = r?.text('currency') ?? 'VND';
    opening.text = Money.groupedInput(
      r?.money('opening_balance') ?? 0,
      currency,
    );
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
      Record? savedRecord;
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
          data.addAll({
            'type': type,
            'is_archived': archived,
            'behavior':
                widget.record?.text('behavior') == 'lending' ||
                    (name.text.trim() == 'Cho vay' && type == 'expense')
                ? 'lending'
                : 'normal',
          });
        }
        if (widget.entity == Entity.tags) {
          if (widget.record?.text('display_name').isNotEmpty ?? false) {
            data['name'] = widget.record!.text('name');
            data['display_name'] = name.text.trim();
          } else {
            data['name'] = normalizeTagName(name.text);
          }
          data['category_id'] = category;
        }
        if (widget.entity == Entity.people) {
          data.addAll({
            'note': note.text,
            'phone_optional': phone.text.trim().isEmpty
                ? null
                : phone.text.trim(),
          });
        }
        savedRecord =
            widget.record?.patch(data) ?? repo.create(widget.entity, data);
        await repo.save(savedRecord!);
      });
      if (mounted) Navigator.pop(context, savedRecord);
    } catch (e) {
      if (mounted) setState(() => error = userError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entityTitle = switch (widget.entity) {
      Entity.accounts => 'tài khoản',
      Entity.categories => 'danh mục',
      Entity.tags => 'thẻ (tag)',
      Entity.people => 'người liên quan',
      _ => widget.entity.name,
    };

    return FormDialog(
      title: widget.record == null
          ? 'Thêm $entityTitle mới'
          : 'Chỉnh sửa $entityTitle',
      busy: busy,
      error: error,
      save: save,
      children: [
        TextField(
          controller: name,
          autofocus: widget.record == null,
          decoration: InputDecoration(labelText: context.tr('Name')),
          textInputAction: TextInputAction.next,
        ),
        if (widget.entity == Entity.tags)
          RecordPicker(
            label: 'Danh mục liên kết',
            value: category,
            records: (ref.watch(recordsProvider(Entity.categories)).value ?? [])
                .where((c) => !c.flag('is_archived') || c.id == category)
                .toList(),
            onChanged: (v) => setState(() => category = v),
          ),
        if ([Entity.accounts, Entity.categories].contains(widget.entity))
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: 'Loại'),
            items:
                (widget.entity == Entity.accounts
                        ? [
                            ('cash', 'Tiền mặt'),
                            ('bank', 'Ngân hàng'),
                            ('e_wallet', 'Ví điện tử'),
                            ('savings', 'Tiết kiệm'),
                            ('other', 'Khác'),
                          ]
                        : [
                            ('expense', 'Chi tiêu'),
                            ('income', 'Thu nhập'),
                            ('both', 'Cả hai'),
                          ])
                    .map(
                      (v) => DropdownMenuItem(value: v.$1, child: Text(v.$2)),
                    )
                    .toList(),
            onChanged: widget.record?.text('behavior') == 'lending'
                ? null
                : (v) => setState(() => type = v!),
          ),
        if (widget.entity == Entity.accounts) ...[
          DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: InputDecoration(labelText: 'Loại tiền tệ'),
            items: Money.exponents.keys
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: widget.record == null
                ? (v) => setState(() => currency = v!)
                : null,
          ),
          TextField(
            controller: opening,
            inputFormatters: [MoneyInputFormatter(allowNegative: true)],
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'Số dư ban đầu',
              hintText: '0',
            ),
          ),
        ],
        if (widget.entity == Entity.people) ...[
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Số điện thoại (tuỳ chọn)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          TextField(
            controller: note,
            decoration: InputDecoration(
              labelText: 'Ghi chú',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            minLines: 1,
            maxLines: 3,
          ),
        ],
        if ([Entity.accounts, Entity.categories].contains(widget.entity))
          Container(
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                title: const Text(
                  'Lưu trữ (ẩn khỏi danh sách chọn)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                value: archived,
                onChanged: (v) => setState(() => archived = v),
              ),
            ),
          ),
        if (widget.record != null &&
            [Entity.tags, Entity.people].contains(widget.entity))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirmDelete(context)) {
                        try {
                          await saveAndSync(
                            ref,
                            (r) => r.remove(widget.record!),
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            setState(() => error = userError(context, e));
                          }
                        }
                      }
                    },
              icon: Icon(Icons.delete_outline, size: 18, color: colors.expense),
              label: Text(
                'Xoá mục này',
                style: TextStyle(color: colors.expense),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AccountDetail
// ─────────────────────────────────────────────────────────────────────────────

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
  final reportRows = Ledger.reportingRows(
    period,
    shareBills: await workspace.repository.db.list(Entity.shareBills),
    shareBillPayments: await workspace.repository.db.list(
      Entity.shareBillPayments,
    ),
    categories: await workspace.repository.db.list(Entity.categories),
  );
  final totals = Ledger.monthly(
    reportRows,
    ref.read(monthProvider),
    account.text('currency'),
  );
  if (!context.mounted) return;

  final colors = context.colors;
  final currency = account.text('currency');

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.primaryAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: colors.primaryAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              account.text('name'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Balance banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SỐ DƯ HIỆN TẠI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Money.format(balance, currency),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Month flow
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.income.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thu tháng này',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Money.format(totals.income, currency),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: colors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.expense.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tháng này',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Money.format(totals.expense, currency),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: colors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Giao dịch gần đây',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Chưa có giao dịch nào trên tài khoản này.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                )
              else
                for (final t in recent.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        TransactionLeadingIcon(type: t.text('type'), size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.text('description').isEmpty
                                ? context.tr(t.text('type'))
                                : t.text('description'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        MoneyText(
                          amountMinor: t.money('amount'),
                          currency: t.text('currency'),
                          direction: t.text('type'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
          onPressed: () {
            Navigator.pop(context);
            showCatalogForm(context, Entity.accounts, record: account);
          },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(context.tr('Sửa tài khoản')),
        ),
      ],
    ),
  );
}
