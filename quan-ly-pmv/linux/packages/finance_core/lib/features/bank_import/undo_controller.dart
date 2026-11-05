import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'undo_slot.dart';

/// One app-scoped owner of a durable discard decision, independent of paging/UI.
class UndoController extends ChangeNotifier {
  final SharedPreferences preferences;
  final String owner;
  final Future<void> Function(String id) finish;
  final VoidCallback changed;
  final Lock _lock = Lock();
  Timer? _timer;
  bool _disposed = false;
  UndoSlot? slot;
  String? error;
  UndoController(this.preferences, this.owner, this.finish, this.changed);

  Future<void> restore() => _lock.synchronized(() async {
    slot = UndoSlot.load(preferences);
    if (slot != null && slot!.owner != owner) {
      await UndoSlot.clear(preferences);
      slot = null;
    }
    if (slot?.isExpired == true) {
      await _finish();
    } else {
      _schedule();
      _notify();
    }
  });

  Future<void> discard(String id) => _lock.synchronized(() async {
    if (_disposed) return;
    if (slot != null && !await _finish()) {
      throw StateError('Không thể bỏ qua giao dịch trước. Vui lòng thử lại.');
    }
    if (_disposed) return;
    slot = UndoSlot.forDraft(owner: owner, draftId: id);
    await slot!.save(preferences);
    _schedule();
    _notify();
  });

  Future<void> undo(String id) => _lock.synchronized(() async {
    if (_disposed || slot?.draftId != id || slot!.isExpired) return;
    _timer?.cancel();
    await UndoSlot.clear(preferences);
    slot = null;
    error = null;
    _notify();
  });

  Future<bool> _finish() async {
    final current = slot;
    if (current == null || _disposed) return !_disposed;
    _timer?.cancel();
    try {
      await finish(current.draftId);
      if (_disposed) return false;
      await UndoSlot.clear(preferences);
      slot = null;
      error = null;
      _notify();
      return true;
    } catch (_) {
      if (_disposed) return false;
      error = 'Đang chờ hoàn tất bỏ qua. Sẽ tự thử lại.';
      _timer = Timer(const Duration(seconds: 3), () {
        unawaited(_lock.synchronized(_finish));
      });
      _notify();
      return false;
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (slot == null || _disposed) return;
    final delay = slot!.deadline.difference(DateTime.now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(_lock.synchronized(_finish));
    });
  }

  void _notify() {
    if (_disposed) return;
    changed();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
