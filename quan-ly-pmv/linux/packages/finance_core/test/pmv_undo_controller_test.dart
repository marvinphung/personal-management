import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_core/features/bank_import/undo_controller.dart';
import 'package:finance_core/features/bank_import/undo_slot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'failed finalize keeps durable ID even if no pending page is loaded; restore retries',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await UndoSlot(
        owner: 'u',
        draftId: 'page-9',
        deadline: DateTime(2020),
      ).save(prefs);
      final failed = UndoController(prefs, 'u', (_) async {
        throw StateError('disk');
      }, () {});
      await failed.restore();
      expect(UndoSlot.load(prefs)!.draftId, 'page-9');
      expect(failed.error, isNotNull);
      failed.dispose();
      final ids = <String>[];
      final retry = UndoController(prefs, 'u', (id) async {
        ids.add(id);
      }, () {});
      await retry.restore();
      expect(ids, ['page-9']);
      expect(UndoSlot.load(prefs), isNull);
      retry.dispose();
    },
  );
  test(
    'second discard finalizes previous decision; stale undo cannot clear newer slot',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final ids = <String>[];
      final c = UndoController(prefs, 'u', (id) async {
        ids.add(id);
      }, () {});
      await c.restore();
      await c.discard('a');
      await c.discard('b');
      await c.undo('a');
      expect(ids, ['a']);
      expect(UndoSlot.load(prefs)!.draftId, 'b');
      await c.undo('b');
      expect(UndoSlot.load(prefs), isNull);
      c.dispose();
    },
  );
}
