import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'bank_draft_repository.dart';
import 'bank_draft.dart';

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
final bankCountProvider = FutureProvider<int>((ref) async {
  ref.watch(bankEventsProvider);
  final workspace = await ref.watch(workspaceProvider.future);
  if (workspace == null || !BankDraftRepository.supported) return 0;
  return ref.read(bankDraftRepositoryProvider).count();
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
