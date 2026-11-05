import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_core/features/bank_import/undo_slot.dart';

void main() {
  group('UndoSlot specifications', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('UndoSlot persists and restores correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      final deadline = DateTime.now().add(const Duration(seconds: 3));

      final slot = UndoSlot(
        owner: 'user-abc',
        draftId: 'draft-123',
        deadline: deadline,
      );

      await slot.save(prefs);

      final restored = UndoSlot.load(prefs);
      expect(restored, isNotNull);
      expect(restored!.owner, equals('user-abc'));
      expect(restored.draftId, equals('draft-123'));
      expect(
        restored.deadline.millisecondsSinceEpoch,
        equals(deadline.millisecondsSinceEpoch),
      );
      expect(restored.isExpired, isFalse);
    });

    test('UndoSlot detects expiry after deadline', () async {
      final prefs = await SharedPreferences.getInstance();
      final past = DateTime.now().subtract(const Duration(seconds: 1));

      final slot = UndoSlot(
        owner: 'user-abc',
        draftId: 'draft-123',
        deadline: past,
      );
      await slot.save(prefs);

      final restored = UndoSlot.load(prefs);
      expect(restored, isNotNull);
      expect(restored!.isExpired, isTrue);
    });

    test('UndoSlot.clear removes stored slot', () async {
      final prefs = await SharedPreferences.getInstance();
      final slot = UndoSlot.forDraft(owner: 'user-abc', draftId: 'draft-123');
      await slot.save(prefs);

      expect(UndoSlot.load(prefs), isNotNull);

      await UndoSlot.clear(prefs);
      expect(UndoSlot.load(prefs), isNull);
    });
  });
}
