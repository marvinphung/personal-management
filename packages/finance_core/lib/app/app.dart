import 'dart:async';
import '../features/bank_import/bank_draft_repository.dart';
import '../features/bank_import/bank_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'language.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'router.dart';
import 'theme.dart';
import '../core/localization/app_language.dart';

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({super.key});
  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _bankEvents;
  bool _openInbox = false;
  bool _readingBalances = false;
  Future<void> _readBalances() async {
    if (_readingBalances || !BankDraftRepository.supported) return;
    _readingBalances = true;
    try {
      final w = await ref.read(workspaceProvider.future);
      if (w == null || !mounted) return;
      final balances = await ref.read(bankDraftRepositoryProvider).balances();
      for (final snapshot in balances) {
        if (!mounted || ref.read(workspaceProvider).value != w) return;
        await w.repository.applyBankBalance(snapshot);
      }
      unawaited(w.sync.sync());
    } catch (_) {
      // Native snapshots remain durable; resume or the next event retries.
    } finally {
      _readingBalances = false;
    }
  }

  Future<void> _readBankIntent() async {
    try {
      if (await ref.read(bankDraftRepositoryProvider).consumeOpenPending() &&
          mounted) {
        setState(() => _openInbox = true);
      }
    } catch (_) {
      /* Normal navigation remains available if the bridge fails. */
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (BankDraftRepository.supported) {
      _bankEvents = ref.read(bankDraftRepositoryProvider).events.stream.listen((
        event,
      ) {
        if (event == 'openPending') _readBankIntent();
        _readBalances();
      });
      _readBankIntent();
      _readBalances();
    }
  }

  @override
  void dispose() {
    _bankEvents?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(workspaceProvider).value?.sync.sync();
      ref.invalidate(pendingBankEventsProvider);
      if (BankDraftRepository.supported) {
        ref.invalidate(bankDraftPageProvider);
        ref.invalidate(bankDraftsProvider);
        ref.invalidate(bankCountProvider);
        ref.invalidate(bankSettingsProvider);
        _readBankIntent();
        _readBalances();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the native owner lifecycle active even while the login route is shown.
    // A restored signed-out session must stop capture and erase the old inbox.
    if (BankDraftRepository.supported) ref.watch(workspaceProvider);
    final signedIn = ref.watch(sessionProvider) != null;
    final language = ref.watch(languageProvider);
    if (_openInbox && signedIn && language != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_openInbox) return;
        ref.read(routerProvider).go('/pending');
        _openInbox = false;
      });
    }
    return MaterialApp.router(
      onGenerateTitle: (context) => context.tr('Personal Finance'),
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('en'), Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: financeTheme(Brightness.light),
      darkTheme: financeTheme(Brightness.dark),
      themeMode: ref.watch(themeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
