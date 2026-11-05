import 'dart:async';
import 'undo_controller.dart';
import '../../core/database/record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'bank_draft_repository.dart';
import 'bank_draft.dart';
import 'undo_slot.dart';

final bankEventsProvider = StreamProvider<String>(
  (ref) => ref
      .watch(bankDraftRepositoryProvider)
      .events
      .stream
      .map((event) => '$event:${DateTime.now().microsecondsSinceEpoch}'),
);

final bankDraftsProvider = FutureProvider<List<BankDraft>>((ref) async {
  ref.watch(bankEventsProvider);
  final workspace = await ref.watch(workspaceProvider.future);
  if (workspace == null || !BankDraftRepository.supported) return [];
  return ref.read(bankDraftRepositoryProvider).pending();
});

/// Returns the pending count minus any active undo slot (0 or 1).
final bankCountProvider = FutureProvider<int>((ref) async {
  ref.watch(bankEventsProvider);
  final workspace = await ref.watch(workspaceProvider.future);
  if (workspace == null || !BankDraftRepository.supported) return 0;
  final rawCount = await ref.read(bankDraftRepositoryProvider).count();
  // Subtract 1 if there is an active undo slot for the current owner
  final prefs = ref.read(preferencesProvider);
  final slot = UndoSlot.load(prefs);
  final userId = workspace.repository.userId;
  if (slot != null && slot.owner == userId) {
    return (rawCount - 1).clamp(0, rawCount);
  }
  return rawCount;
});

final bankSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(bankEventsProvider);
  await ref.watch(workspaceProvider.future);
  return ref.read(bankDraftRepositoryProvider).settings();
});

final bankDraftPageProvider = FutureProvider.family<List<BankDraft>, int>((
  ref,
  offset,
) async {
  ref.watch(bankEventsProvider);
  final workspace = await ref.watch(workspaceProvider.future);
  if (workspace == null || !BankDraftRepository.supported) return [];
  return ref.read(bankDraftRepositoryProvider).pending(offset: offset);
});

/// Top-5 category IDs for [type] ('income' or 'expense') ranked by transaction
/// frequency across the current month and the two preceding months.
///
/// Returns a list of Records from the categories table, limited to 5.
final categoryRankProvider = FutureProvider.family<List<String>, String>((
  ref,
  type,
) async {
  ref.watch(databaseEventsProvider);
  final w = await ref.watch(workspaceProvider.future);
  if (w == null) return [];
  final now = DateTime.now();
  // Build start of the window: first day three months ago
  final windowStart = DateTime(now.year, now.month - 2, 1);
  final windowEnd = DateTime(now.year, now.month + 1, 1); // exclusive

  // Count category_id occurrences for transactions in window
  final counts = <String, int>{};
  for (var mo = 0; mo < 3; mo++) {
    final month = DateTime(now.year, now.month - mo);
    final rows = await w.db.list(Entity.transactions, month: month);
    for (final t in rows) {
      if (t.deleted) continue;
      if (t.text('type') != type) continue;
      final cat = t.text('category_id');
      if (cat.isEmpty) continue;
      final date = t.date('occurred_at');
      if (date.isBefore(windowStart) || !date.isBefore(windowEnd)) continue;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => e.key).toList();
});

final undoControllerProvider = Provider<UndoController?>((ref) {
  final w = ref.watch(workspaceProvider).value;
  if (w == null || !BankDraftRepository.supported) return null;
  final repo = ref.read(bankDraftRepositoryProvider);
  final owner = w.repository.userId;
  final controller = UndoController(
    ref.read(preferencesProvider),
    owner,
    (id) => repo.ignoreId(owner, id),
    () {
      ref.invalidate(bankCountProvider);
      ref.invalidate(bankDraftPageProvider);
      unawaited(repo.refreshWidget().catchError((Object _) {}));
    },
  );
  ref.onDispose(controller.dispose);
  unawaited(Future(controller.restore));
  return controller;
});
