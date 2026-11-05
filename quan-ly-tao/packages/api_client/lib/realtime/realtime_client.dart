import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../models/models.dart';
import '../session/session_store.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class InboxSnapshotEvent {
  final int inboxRevision;
  final int pendingCount;
  final List<PendingBankEventDto> events;

  const InboxSnapshotEvent({
    required this.inboxRevision,
    required this.pendingCount,
    required this.events,
  });
}

class SyncRequiredEvent {
  final List<String> entityTypes;
  final int serverRevision;

  const SyncRequiredEvent({
    required this.entityTypes,
    required this.serverRevision,
  });
}

class RealtimeClient {
  final String baseUrl;
  final SessionStore sessionStore;

  WebSocket? _socket;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  final _snapshotController = StreamController<InboxSnapshotEvent>.broadcast();
  final _syncRequiredController = StreamController<SyncRequiredEvent>.broadcast();

  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Chunk buffering: snapshot_id -> list of chunked events
  final Map<String, List<PendingBankEventDto>> _chunkBuffers = {};

  RealtimeClient({
    required this.baseUrl,
    required this.sessionStore,
  });

  Stream<RealtimeConnectionState> get connectionState => _stateController.stream;
  Stream<InboxSnapshotEvent> get inboxSnapshots => _snapshotController.stream;
  Stream<SyncRequiredEvent> get syncRequiredEvents => _syncRequiredController.stream;
  RealtimeConnectionState get currentState => _state;

  Uri _buildWsUri() {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final wsBase = cleanBase.replaceFirst(RegExp(r'^http'), 'ws');
    return Uri.parse('$wsBase/realtime');
  }

  void _setState(RealtimeConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  Future<void> connect() async {
    if (_isDisposed) return;
    if (_state == RealtimeConnectionState.connected || _state == RealtimeConnectionState.connecting) {
      return;
    }

    _setState(_reconnectAttempts > 0
        ? RealtimeConnectionState.reconnecting
        : RealtimeConnectionState.connecting);

    final token = await sessionStore.getToken();
    if (token == null) {
      _setState(RealtimeConnectionState.disconnected);
      return;
    }

    final uri = _buildWsUri();
    try {
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      );
      _socket = socket;
      _reconnectAttempts = 0;
      _setState(RealtimeConnectionState.connected);

      _startPingTimer();

      socket.listen(
        _onMessage,
        onError: (err) {
          _onDisconnect();
        },
        onDone: () {
          _onDisconnect();
        },
      );
    } catch (_) {
      _onDisconnect();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_socket != null && _state == RealtimeConnectionState.connected) {
        final pingMsg = jsonEncode({
          'protocol_version': '1.0',
          'type': 'ping',
          'connection_id': '',
          'inbox_revision': 0,
          'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
        });
        _socket?.add(pingMsg);
      }
    });
  }

  void _onMessage(dynamic rawData) {
    try {
      final msg = jsonDecode(rawData.toString());
      if (msg is! Map) return;

      final type = msg['type'] as String?;
      final inboxRevision = (msg['inbox_revision'] as num?)?.toInt() ?? 0;
      final data = msg['data'] as Map<String, dynamic>? ?? {};

      if (type == 'inbox.snapshot') {
        final pendingCount = (data['pending_count'] as num?)?.toInt() ?? 0;
        final rawEvents = data['events'] as List<dynamic>? ?? [];
        final events = rawEvents
            .map((e) => PendingBankEventDto.fromJson(e as Map<String, dynamic>))
            .toList();

        _snapshotController.add(InboxSnapshotEvent(
          inboxRevision: inboxRevision,
          pendingCount: pendingCount,
          events: events,
        ));
      } else if (type == 'inbox.snapshot_chunk') {
        final snapshotId = data['snapshot_id'] as String? ?? '';
        final rawEvents = data['events'] as List<dynamic>? ?? [];
        final events = rawEvents
            .map((e) => PendingBankEventDto.fromJson(e as Map<String, dynamic>))
            .toList();

        _chunkBuffers.putIfAbsent(snapshotId, () => []).addAll(events);
      } else if (type == 'inbox.snapshot_complete') {
        final snapshotId = data['snapshot_id'] as String? ?? '';
        final pendingCount = (data['pending_count'] as num?)?.toInt() ?? 0;
        final buffered = _chunkBuffers.remove(snapshotId) ?? [];

        _snapshotController.add(InboxSnapshotEvent(
          inboxRevision: inboxRevision,
          pendingCount: pendingCount,
          events: buffered,
        ));
      } else if (type == 'sync.required') {
        final rawEntityTypes = data['entity_types'] as List<dynamic>? ?? [];
        final entityTypes = rawEntityTypes.map((e) => e.toString()).toList();
        final serverRev = (data['server_revision'] as num?)?.toInt() ?? 0;

        _syncRequiredController.add(SyncRequiredEvent(
          entityTypes: entityTypes,
          serverRevision: serverRev,
        ));
      }
    } catch (_) {
      // Discard malformed frames
    }
  }

  void _onDisconnect() {
    _pingTimer?.cancel();
    _socket?.close();
    _socket = null;

    if (_isDisposed) {
      _setState(RealtimeConnectionState.disconnected);
      return;
    }

    _setState(RealtimeConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Exponential backoff with jitter: min 1.0s, max 30s, factor 1.5, ±20% jitter
    final baseSeconds = min(30.0, 1.0 * pow(1.5, _reconnectAttempts - 1));
    final jitter = (Random().nextDouble() * 0.4 - 0.2) * baseSeconds;
    final delayMs = ((baseSeconds + jitter) * 1000).toInt();

    _reconnectTimer = Timer(Duration(milliseconds: max(500, delayMs)), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _socket?.close();
    _socket = null;
    _setState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _stateController.close();
    _snapshotController.close();
    _syncRequiredController.close();
  }
}
