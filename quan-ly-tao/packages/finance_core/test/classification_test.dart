import 'package:finance_core/core/database/record.dart';
import 'package:finance_core/features/bank_import/bank_confirmation.dart';
import 'package:finance_core/features/catalog/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleEvent = Record(Entity.pendingBankEvents, {
    'id': 'ev-1',
    'bank_code': 'bidv',
    'owner_account_snapshot': '001234567890',
    'amount_vnd': 720000,
    'direction': 'income',
    'occurred_at': '2026-10-03T14:30:00Z',
    'bank_description': 'BIDV NHAN TIEN',
  });

  final sampleCategories = [
    Record(Entity.categories, {'id': 'cat-1', 'direction': 'income', 'name': 'Lương', 'icon': 'payments', 'archived': false, 'seed_rank': 1}),
    Record(Entity.categories, {'id': 'cat-2', 'direction': 'income', 'name': 'Thưởng', 'icon': 'stars', 'archived': false, 'seed_rank': 2}),
    Record(Entity.categories, {'id': 'cat-3', 'direction': 'income', 'name': 'Kinh doanh', 'icon': 'store', 'archived': false, 'seed_rank': 3}),
    Record(Entity.categories, {'id': 'cat-4', 'direction': 'income', 'name': 'Làm thêm', 'icon': 'work', 'archived': false, 'seed_rank': 4}),
    Record(Entity.categories, {'id': 'cat-5', 'direction': 'income', 'name': 'Được tặng', 'icon': 'card_giftcard', 'archived': false, 'seed_rank': 5}),
    Record(Entity.categories, {'id': 'cat-6', 'direction': 'income', 'name': 'Thu khác', 'icon': 'attach_money', 'archived': false, 'seed_rank': 6}),
  ];

  final sampleTags = [
    Record(Entity.tags, {'id': 'tag-1', 'category_id': 'cat-1', 'name': 'Lương chính', 'archived': false}),
    Record(Entity.tags, {'id': 'tag-2', 'category_id': 'cat-1', 'name': 'Phụ cấp', 'archived': false}),
    Record(Entity.tags, {'id': 'tag-3', 'category_id': 'cat-2', 'name': 'Thưởng Tết', 'archived': false}),
  ];

  testWidgets('CategoryGridPicker displays top 5 categories and Khác tile', (tester) async {
    Record? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryGridPicker(
            direction: 'income',
            categories: sampleCategories,
            selectedCategoryId: null,
            onSelected: (cat) => selected = cat,
          ),
        ),
      ),
    );

    expect(find.text('Lương'), findsOneWidget);
    expect(find.text('Thưởng'), findsOneWidget);
    expect(find.text('Kinh doanh'), findsOneWidget);
    expect(find.text('Làm thêm'), findsOneWidget);
    expect(find.text('Được tặng'), findsOneWidget);
    expect(find.text('Khác…'), findsOneWidget);

    // Tap first category
    await tester.tap(find.text('Lương'));
    expect(selected?.id, 'cat-1');
  });

  testWidgets('BankEventClassificationSheet enforces category selection before acceptance', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool accepted = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BankEventClassificationSheet(
              pendingEvent: sampleEvent,
              categories: sampleCategories,
              tags: sampleTags,
              onAccept: (catId, tagIds, note) async {
                accepted = true;
              },
              onDiscard: () async {},
            ),
          ),
        ),
      ),
    );

    // Accept button should initially be disabled
    final buttonFinder = find.widgetWithText(FilledButton, 'Chấp nhận (Lưu vào sổ)');
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNull);

    // Tap 'Lương' category
    await tester.tap(find.text('Lương'));
    await tester.pump();

    // Now button should be enabled
    final enabledButton = tester.widget<FilledButton>(buttonFinder);
    expect(enabledButton.onPressed, isNotNull);

    // Verify tag chips for 'cat-1' appeared
    expect(find.text('Lương chính'), findsOneWidget);
    expect(find.text('Phụ cấp'), findsOneWidget);

    // Tap 'Lương chính' tag
    await tester.tap(find.text('Lương chính'));
    await tester.pump();

    // Submit
    await tester.tap(buttonFinder);
    await tester.pump();
    expect(accepted, true);
  });
}
