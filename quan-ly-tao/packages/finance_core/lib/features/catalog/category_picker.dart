import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/record.dart';
import 'inline_create.dart';

class CategoryGridPicker extends ConsumerWidget {
  final String direction; // 'income' or 'expense'
  final List<Record> categories;
  final String? selectedCategoryId;
  final ValueChanged<Record> onSelected;

  const CategoryGridPicker({
    super.key,
    required this.direction,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  IconData _iconForName(String? name) {
    return switch (name) {
      'restaurant' => Icons.restaurant,
      'commute' => Icons.directions_car,
      'shopping_bag' => Icons.shopping_bag,
      'home' => Icons.home,
      'sports_esports' => Icons.sports_esports,
      'health_and_safety' => Icons.health_and_safety,
      'school' => Icons.school,
      'redeem' => Icons.card_giftcard,
      'flight' => Icons.flight,
      'payments' => Icons.payments,
      'stars' => Icons.stars,
      'store' => Icons.store,
      'work' => Icons.work,
      'attach_money' => Icons.attach_money,
      _ => Icons.category,
    };
  }

  void _openFullCatalog(BuildContext context, WidgetRef ref) async {
    final activeCategories = categories
        .where((c) => (c.text('direction') == direction || c.text('direction').isEmpty) && !c.flag('archived'))
        .toList();

    final picked = await showModalBottomSheet<Record>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tất cả danh mục',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo mới'),
                    onPressed: () async {
                      final created = await showInlineCreateCategory(ctx, ref, direction: direction);
                      if (created != null && ctx.mounted) {
                        Navigator.pop(ctx, created);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: activeCategories.length,
                itemBuilder: (ctx, idx) {
                  final cat = activeCategories[idx];
                  final isSelected = cat.id == selectedCategoryId;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      foregroundColor: isSelected
                          ? Theme.of(ctx).colorScheme.onPrimary
                          : Theme.of(ctx).colorScheme.onSurface,
                      child: Icon(_iconForName(cat.text('icon')), size: 20),
                    ),
                    title: Text(cat.text('name')),
                    selected: isSelected,
                    onTap: () => Navigator.pop(ctx, cat),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCategories = categories
        .where((c) => (c.text('direction') == direction || c.text('direction').isEmpty) && !c.flag('archived'))
        .toList();

    // Take top 5
    final top5 = activeCategories.take(5).toList();

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.25,
      children: [
        for (final cat in top5) ...[
          _GridTile(
            title: cat.text('name'),
            icon: _iconForName(cat.text('icon')),
            isSelected: cat.id == selectedCategoryId,
            onTap: () => onSelected(cat),
          ),
        ],
        // Fill empty slots if fewer than 5
        for (int i = top5.length; i < 5; i++) const SizedBox.shrink(),
        // 6th tile: "Khác..."
        _GridTile(
          title: 'Khác…',
          icon: Icons.more_horiz,
          isSelected: false,
          onTap: () => _openFullCatalog(context, ref),
        ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GridTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: isSelected ? primary.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: isSelected ? primary : theme.colorScheme.onSurface),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
