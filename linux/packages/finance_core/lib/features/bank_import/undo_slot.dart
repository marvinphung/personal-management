import 'package:shared_preferences/shared_preferences.dart';

/// Persists a single "Bỏ qua" undo slot across app restarts.
///
/// Key: 'undo_slot'  (stored as '|'-joined fields)
/// Format: owner|draftId|deadlineEpochMs
class UndoSlot {
  final String owner;
  final String draftId;
  final DateTime deadline;

  const UndoSlot({
    required this.owner,
    required this.draftId,
    required this.deadline,
  });

  static const _key = 'undo_slot';
  static const _sep = '|';

  bool get isExpired => DateTime.now().isAfter(deadline);

  /// Persist to SharedPreferences.
  Future<void> save(SharedPreferences prefs) async {
    final encoded =
        '$owner$_sep$draftId$_sep${deadline.millisecondsSinceEpoch}';
    await prefs.setString(_key, encoded);
  }

  /// Load from SharedPreferences. Returns null if nothing stored.
  static UndoSlot? load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final parts = raw.split(_sep);
    if (parts.length != 3) return null;
    final ms = int.tryParse(parts[2]);
    if (ms == null) return null;
    return UndoSlot(
      owner: parts[0],
      draftId: parts[1],
      deadline: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Clear the stored slot.
  static Future<void> clear(SharedPreferences prefs) => prefs.remove(_key);

  /// Create a new slot expiring [seconds] from now (default 3 s).
  factory UndoSlot.forDraft({
    required String owner,
    required String draftId,
    int seconds = 3,
  }) => UndoSlot(
    owner: owner,
    draftId: draftId,
    deadline: DateTime.now().add(Duration(seconds: seconds)),
  );
}
