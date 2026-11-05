import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/utils/money.dart';

class SpendingChart extends StatefulWidget {
  final List<int> days;
  final DateTime month;
  final String currency;
  const SpendingChart({
    super.key,
    required this.days,
    required this.month,
    required this.currency,
  });
  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  int? selected;
  @override
  void didUpdateWidget(SpendingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        oldWidget.currency != widget.currency) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final peak = widget.days.fold<int>(0, (a, b) => a > b ? a : b);
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.primaryAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Chi tiêu theo ngày',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (peak > 0)
                  Text(
                    'Cao nhất: ${Money.format(peak, widget.currency)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Selected day info pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected == null
                    ? colors.bgElevated
                    : colors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selected == null
                    ? 'Chạm vào cột ngày để xem số tiền chi tiêu.'
                    : 'Ngày ${selected! + 1}/${widget.month.month}/${widget.month.year} · ${Money.format(widget.days[selected!], widget.currency)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected == null
                      ? FontWeight.normal
                      : FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: selected == null
                      ? colors.textSecondary
                      : colors.primaryAccent,
                ),
              ),
            ),
            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth / widget.days.length).clamp(
                  36.0,
                  70.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(widget.days.length, (i) {
                      final amount = widget.days[i];
                      final isSelected = selected == i;
                      final label =
                          'Ngày ${i + 1}/${widget.month.month}: ${Money.format(amount, widget.currency)}';
                      return Semantics(
                        button: true,
                        label: label,
                        selected: isSelected,
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            onTap: () => setState(() => selected = i),
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: width,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 130,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: width - 14,
                                        height: peak == 0 || amount == 0
                                            ? 3
                                            : (amount / peak * 130)
                                                  .clamp(4, 130)
                                                  .toDouble(),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? PmvColors.brandGold
                                              : amount == 0
                                              ? colors.borderSubtle
                                              : colors.primaryAccent,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(5),
                                                bottom: Radius.circular(2),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? colors.primaryAccent
                                          : colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            if (peak == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    'Chưa có chi tiêu nào trong tháng này.',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
