import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'bank_draft_repository.dart';
import 'bank_draft.dart';
import 'package:api_client/api_client.dart';

final pendingInboxRealtimeProvider = StreamProvider<InboxSnapshotEvent>((ref) {
  return ref.watch(realtimeClientProvider).inboxSnapshots;
});

final pendingInboxRefreshTickProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(minutes: 5), (tick) => tick);
});

/// Server-backed inbox shared by Android and iOS user apps.
final pendingBankEventsProvider = FutureProvider<List<PendingBankEventDto>>((ref) async {
  // A foreground WebSocket snapshot refreshes the visible inbox immediately.
  // The five-minute tick is the recovery path when realtime is unavailable.
  ref.watch(pendingInboxRealtimeProvider);
  ref.watch(pendingInboxRefreshTickProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.read(apiClientProvider).getPendingEvents();
});

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
