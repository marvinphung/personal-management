import 'package:flutter/material.dart';
import '../core/localization/app_language.dart';
import '../core/utils/money.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppPage
// ─────────────────────────────────────────────────────────────────────────────

/// Standard page wrapper providing responsive max-width, padding, and safe area.
class AppPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool scrollable;

  const AppPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.maxWidth = 640,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      );
    }

    return SafeArea(child: content);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

/// Section header với title dạng thường (không uppercase — dễ đọc tiếng Việt)
/// và optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: colors.textSecondary,
              ),
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SummaryCard
// ─────────────────────────────────────────────────────────────────────────────

/// Thẻ tổng quan tháng — hiển thị dòng tiền ròng, thu và chi.
/// Số tiền dùng tabular figures, tương phản rõ ràng.
class SummaryCard extends StatelessWidget {
  final int balanceMinor;
  final int incomeMinor;
  final int expenseMinor;
  final String currency;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.balanceMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    this.currency = 'VND',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = balanceMinor >= 0;

    // Màu nền card theo dòng tiền
    final cardBg = isDark
        ? (isPositive
              ? colors.primaryAccent.withValues(alpha: 0.08)
              : colors.expense.withValues(alpha: 0.06))
        : colors.bgSurface;

    final netColor = isPositive ? colors.income : colors.expense;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.borderSubtle),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: netColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Dòng tiền tháng'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Số tiền ròng — lớn, nổi bật
              Text(
                Money.format(balanceMinor, currency),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: netColor,
                ),
              ),
              if (balanceMinor < 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Bội chi tháng này',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.expense.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Thu / Chi row
              Container(
                decoration: BoxDecoration(
                  color: isDark ? colors.bgElevated : const Color(0xFFF0FAF8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // Thu nhập
                    Expanded(
                      child: _MetricCell(
                        icon: Icons.south_rounded,
                        iconColor: colors.income,
                        label: context.tr('Income'),
                        value: Money.format(incomeMinor, currency),
                        valueColor: colors.income,
                        isLeft: true,
                      ),
                    ),
                    // Divider dọc
                    Container(width: 1, height: 40, color: colors.borderSubtle),
                    // Chi tiêu
                    Expanded(
                      child: _MetricCell(
                        icon: Icons.north_rounded,
                        iconColor: colors.expense,
                        label: context.tr('Expense'),
                        value: Money.format(expenseMinor, currency),
                        valueColor: colors.expense,
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final bool isLeft;

  const _MetricCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isLeft ? 14 : 12,
        right: isLeft ? 12 : 14,
        top: 12,
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MoneyText
// ─────────────────────────────────────────────────────────────────────────────

/// Money formatted text with semantic color for income/expense and tabular figures.
class MoneyText extends StatelessWidget {
  final int amountMinor;
  final String currency;
  final String? direction; // 'income', 'expense', or null
  final TextStyle? style;
  final bool showPrefix;

  const MoneyText({
    super.key,
    required this.amountMinor,
    this.currency = 'VND',
    this.direction,
    this.style,
    this.showPrefix = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefix = showPrefix
        ? (direction == 'income' ? '+ ' : (direction == 'expense' ? '− ' : ''))
        : '';
    final color = direction == 'income'
        ? colors.income
        : (direction == 'expense' ? colors.expense : colors.textPrimary);

    return Text(
      '$prefix${Money.format(amountMinor, currency)}',
      style:
          (style ??
                  TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ))
              .copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsGroup
// ─────────────────────────────────────────────────────────────────────────────

/// Grouped container for settings or form tiles.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final String? title;

  const SettingsGroup({super.key, required this.children, this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
        Material(
          color: colors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56, // thụt lề phù hợp với leading icon 24dp
                    endIndent: 0,
                    color: colors.borderSubtle,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatMetricTile — widget nhỏ hiển thị 1 chỉ số (dùng trong dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class StatMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const StatMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: valueColor ?? colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TransactionLeadingIcon — icon avatar cho giao dịch
// ─────────────────────────────────────────────────────────────────────────────

class TransactionLeadingIcon extends StatelessWidget {
  final String type; // 'income', 'expense', 'transfer'
  final double size;

  const TransactionLeadingIcon({super.key, required this.type, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, icon) = switch (type) {
      'income' => (colors.income, Icons.south_rounded),
      'transfer' => (colors.textMuted, Icons.swap_horiz_rounded),
      _ => (colors.expense, Icons.north_rounded),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PmvDivider — divider mảnh giữa các nhóm ngày trong danh sách
// ─────────────────────────────────────────────────────────────────────────────

class PmvDivider extends StatelessWidget {
  const PmvDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.colors.borderSubtle);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DateGroupHeader — header nhóm ngày trong danh sách giao dịch
// ─────────────────────────────────────────────────────────────────────────────

class DateGroupHeader extends StatelessWidget {
  final String date;
  final String? totalAmount; // optional: tổng chi trong ngày

  const DateGroupHeader({super.key, required this.date, this.totalAmount});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      color: colors.bgCanvas,
      child: Row(
        children: [
          Text(
            date,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          if (totalAmount != null) ...[
            const SizedBox(width: 8),
            Text(
              totalAmount!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
