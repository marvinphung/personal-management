import 'package:flutter/material.dart';
import '../core/localization/app_language.dart';
import '../core/utils/money.dart';
import 'theme.dart';

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
        child: Padding(
          padding: padding,
          child: child,
        ),
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

/// Standard section header with uppercase title and optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.textSecondary,
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Prominent summary card displaying current month balance, total income, and total expense.
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Total Balance').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Money.format(balanceMinor, currency),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_downward, size: 14, color: colors.income),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Income'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(incomeMinor, currency),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: colors.borderSubtle,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_upward, size: 14, color: colors.expense),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Expense'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(expenseMinor, currency),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.expense,
                            ),
                          ),
                        ],
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

/// Money formatted text with semantic color for income/expense.
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
      style: (style ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
          .copyWith(color: color),
    );
  }
}

/// Grouped container for settings or form tiles.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final String? title;

  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
  });

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
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
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
                    indent: 16,
                    endIndent: 16,
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
