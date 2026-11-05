import 'package:flutter/material.dart';
import '../../core/localization/app_language.dart';
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Daily spending'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${context.tr('Highest day')}: ${Money.format(peak, widget.currency)}',
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? context.tr(
                      'Tap a day to see its spending. Swipe to see all days.',
                    )
                  : '${selected! + 1}/${widget.month.month}/${widget.month.year} · ${Money.format(widget.days[selected!], widget.currency)}',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth / widget.days.length).clamp(
                  36.0,
                  80.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(widget.days.length, (i) {
                      final amount = widget.days[i];
                      final label =
                          '${i + 1}/${widget.month.month}: ${Money.format(amount, widget.currency)}';
                      return Semantics(
                        button: true,
                        label: label,
                        selected: selected == i,
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            onTap: () => setState(() => selected = i),
                            child: SizedBox(
                              width: width,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 150,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: width - 12,
                                        height: peak == 0 || amount == 0
                                            ? 2
                                            : (amount / peak * 150)
                                                  .clamp(3, 150)
                                                  .toDouble(),
                                        decoration: BoxDecoration(
                                          color: selected == i
                                              ? colors.tertiary
                                              : amount == 0
                                              ? colors.outlineVariant
                                              : colors.primary,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${i + 1}'),
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
                child: Text(context.tr('No expenses this month.')),
              ),
          ],
        ),
      ),
    );
  }
}
