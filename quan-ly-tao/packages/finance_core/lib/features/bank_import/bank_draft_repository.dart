import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bank_draft.dart';

final bankDraftRepositoryProvider = Provider<BankDraftRepository>((ref) {
  final repository = BankDraftRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Only this adapter knows platform method names. Linux never invokes the channel.
class BankDraftRepository {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final MethodChannel channel;
  final events = StreamController<String>.broadcast();
  String? _owner;
  BankDraftRepository({
    this.channel = const MethodChannel('personal_finance/bank_inbox'),
  }) {
    if (supported) {
      channel.setMethodCallHandler((call) async {
        events.add(call.method);
      });
    }
  }
  Future<void> setOwner(String? owner) async {
    if (!supported) {
      _owner = owner;
      return;
    }
    try {
      await channel.invokeMethod<void>('setOwner', {'owner': owner});
    } on MissingPluginException {
      // Optional native inbox not registered
    }
    _owner = owner;
  }

  Future<T?> _call<T>(String method, [Map<String, dynamic> args = const {}]) async {
    if (!supported) return null;
    try {
      return await channel.invokeMethod<T>(method, {'owner': _owner, ...args});
    } on MissingPluginException {
      return null;
    }
  }

  Future<List<BankDraft>> pending({int offset = 0}) async {
    if (!supported) return [];
    return ((await _call<List>('pending', {'offset': offset})) ?? [])
        .map(
          (row) => BankDraft.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> balances() async {
    if (!supported) return [];
    return ((await _call<List>('balances')) ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<int> count() async => supported ? (await _call<int>('count') ?? 0) : 0;

  Future<Map<String, dynamic>> settings() async {
    if (!supported) return const {'sources': []};
    final res = await _call<Map>('getSettings');
    if (res == null) return const {'sources': []};
    return Map<String, dynamic>.from(res);
  }

  Future<void> configure(Map<String, dynamic> values) async {
    // The collector app owns this optional Android channel. The User app also
    // runs on Android but deliberately does not register it; treating the
    // channel as required here prevented every signed-in User workspace from
    // opening with MissingPluginException.
    await _call<void>('configure', values);
  }

  Future<void> finish(BankDraft draft, {required bool confirmed}) async {
    if (!supported) {
      throw UnsupportedError('Native bank inbox is not supported on this device/build');
    }
    if (draft.owner != _owner) {
      throw const FormatException('Please sign in again');
    }
    await channel.invokeMethod<void>('finish', {
      'owner': _owner,
      'id': draft.id,
      'status': confirmed ? 'confirmed' : 'ignored',
    });
  }

  Future<void> reconnect() async {
    if (!supported) return;
    await channel.invokeMethod<void>('reconnect', {'owner': _owner});
  }

  Future<void> openSettings() async {
    if (!supported) return;
    await channel.invokeMethod<void>('openSettings', {'owner': _owner});
  }

  Future<bool> consumeOpenPending() async =>
      supported && (await _call<bool>('consumeOpenPending') ?? false);

  Future<Map<String, dynamic>> parse(String bank, String text) async {
    if (!supported) return const {};
    final res = await channel.invokeMethod<Map>('parse', {
      'owner': _owner,
      'bank': bank,
      'text': text,
    });
    if (res == null) return const {};
    return Map<String, dynamic>.from(res);
  }
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
    events.close();
  }
}
