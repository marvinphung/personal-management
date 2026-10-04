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
      const bool.fromEnvironment('BANK_INBOX_NATIVE_ENABLED') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
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
    if (!supported) return;
    await channel.invokeMethod<void>('setOwner', {'owner': owner});
    _owner = owner;
  }

  Future<T?> _call<T>(String method, [Map<String, dynamic> args = const {}]) =>
      channel.invokeMethod<T>(method, {'owner': _owner, ...args});
  Future<List<BankDraft>> pending({int offset = 0}) async =>
      ((await _call<List>('pending', {'offset': offset})) ?? [])
          .map(
            (row) => BankDraft.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
  Future<List<Map<String, dynamic>>> balances() async =>
      ((await _call<List>('balances')) ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Future<int> count() async => await _call<int>('count') ?? 0;
  Future<Map<String, dynamic>> settings() async =>
      Map<String, dynamic>.from((await _call<Map>('getSettings'))!);
  Future<void> configure(Map<String, dynamic> values) =>
      _call<void>('configure', values);
  Future<void> finish(BankDraft draft, {required bool confirmed}) {
    if (draft.owner != _owner) {
      throw const FormatException('Please sign in again');
    }
    return _call<void>('finish', {
      'id': draft.id,
      'status': confirmed ? 'confirmed' : 'ignored',
    });
  }

  Future<void> reconnect() => _call<void>('reconnect');
  Future<void> openSettings() => _call<void>('openSettings');
  Future<bool> consumeOpenPending() async =>
      supported && (await _call<bool>('consumeOpenPending') ?? false);
  Future<Map<String, dynamic>> parse(String bank, String text) async =>
      Map<String, dynamic>.from(
        (await _call<Map>('parse', {'bank': bank, 'text': text}))!,
      );
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
    events.close();
  }
}
