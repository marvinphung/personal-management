import 'package:flutter/material.dart';
import '../../core/database/record.dart';
import '../../core/utils/money.dart';

class ShareBillControls extends StatelessWidget {
  final bool income, enabled, linked;
  final int people, paidPeople, minimumPaid;
  final ValueChanged<int>? onPaidPeople;
  final List<Record> bills;
  final String? billId;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<int> onPeople;
  final ValueChanged<String?> onBill;
  const ShareBillControls({
    super.key,
    required this.income,
    required this.enabled,
    this.linked = false,
    required this.people,
    this.paidPeople = 1,
    this.minimumPaid = 1,
    this.onPaidPeople,
    this.bills = const [],
    this.billId,
    required this.onEnabled,
    required this.onPeople,
    required this.onBill,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(income ? 'Nhận Share Bill' : 'Chia bill với nhóm'),
        subtitle: linked
            ? const Text('Giao dịch đã liên kết Share Bill')
            : null,
        value: enabled,
        onChanged: linked ? null : onEnabled,
      ),
      if (enabled) ...[
        if (income) ...[
          if (bills.isEmpty)
            const Text('Chưa có Share Bill chưa hoàn tất cùng tiền tệ.'),
          if (bills.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(
                'share-bill-picker-$billId-${bills.map((b) => b.id).join()}',
              ),
              initialValue: bills.any((b) => b.id == billId) ? billId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chọn Share Bill'),
              items: [
                for (final b in bills)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      '${Money.format(b.money('total_amount'), b.text('currency'))} · ${b.money('num_paid')}/${b.money('num_people')} người',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onBill,
            ),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                income
                    ? 'Số người trả trong lần nhận'
                    : 'Tổng số người (gồm bạn)',
              ),
            ),
            IconButton(
              tooltip: 'Giảm số người',
              onPressed: people > 1 ? () => onPeople(people - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$people', key: const ValueKey('share-bill-people')),
            IconButton(
              tooltip: 'Tăng số người',
              onPressed: people < 9999 ? () => onPeople(people + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (!income)
          Row(
            children: [
              const Expanded(child: Text('Số người đã trả')),
              IconButton(
                tooltip: 'Giảm số người đã trả',
                onPressed: paidPeople > minimumPaid && onPaidPeople != null
                    ? () => onPaidPeople!(paidPeople - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$paidPeople',
                key: const ValueKey('share-bill-paid-people'),
              ),
              IconButton(
                tooltip: 'Tăng số người đã trả',
                onPressed: onPaidPeople != null && paidPeople < 9999
                    ? () => onPaidPeople!(paidPeople + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        Text(
          income
              ? 'Một lần chuyển tiền có thể trả hộ nhiều người.'
              : 'Mặc định đã trả 1 người — chính bạn. Không tạo thêm giao dịch thu.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
