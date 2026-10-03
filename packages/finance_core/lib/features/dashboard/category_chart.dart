import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/money.dart';

class CategoryChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final String currency;
  const CategoryChart({
    super.key,
    required this.entries,
    required this.currency,
  });
  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total <= 0) return const SizedBox.shrink();
    final base = Theme.of(context).colorScheme;
    final colors = [
      base.primary,
      base.tertiary,
      base.secondary,
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            label: entries
                .map((e) => '${e.key}: ${Money.format(e.value, currency)}')
                .join(', '),
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(
                painter: _Donut(
                  entries.map((e) => e.value / total).toList(),
                  colors,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: FittedBox(
                      child: Text(Money.format(total, currency)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                entries.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: colors[i % colors.length],
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entries[i].key)),
                      Text(
                        '${(BigInt.from(entries[i].value) * BigInt.from(100) ~/ BigInt.from(total))}%',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Donut extends CustomPainter {
  final List<double> shares;
  final List<Color> colors;
  _Donut(this.shares, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * math.pi * 2;
      canvas.drawArc(
        rect.deflate(18),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}
