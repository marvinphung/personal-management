import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
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
    if (entries.any((e) => e.value < 0)) {
      // A donut cannot represent negative net costs; retain signed amounts.
      return Column(
        children: [
          for (final entry in entries)
            ListTile(
              title: Text(entry.key),
              trailing: Text(Money.format(entry.value, currency)),
            ),
        ],
      );
    }
    if (total <= 0) return const SizedBox.shrink();
    final colors = context.colors;

    final palette = [
      colors.primaryAccent,
      PmvColors.brandGold,
      const Color(0xFF0288D1),
      const Color(0xFF7B1FA2),
      const Color(0xFFE64A19),
      const Color(0xFF00796B),
      const Color(0xFFC2185B),
      const Color(0xFF5D4037),
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
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _Donut(
                  entries.map((e) => e.value / total).toList(),
                  palette,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: FittedBox(
                      child: Text(
                        Money.format(total, currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.textPrimary,
                        ),
                      ),
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
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(BigInt.from(entries[i].value) * BigInt.from(100) ~/ BigInt.from(total))}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.textSecondary,
                        ),
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
        rect.deflate(16),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}
