# Android bank notification inbox

Implementation checklist:
- [x] Inspect existing shared Flutter form, Drift repository and native launcher.
- [x] Pure Kotlin parsing + sample tests (failure before amount; VND/USD integers).
- [x] Native source registry, extractor, listener and Room inbox.
- [x] Deduplication, owner lifecycle, raw-data retention.
- [x] MethodChannel repository and pending review through existing form.
- [x] Idempotent canonical confirmation and existing sync.
- [x] Native 2x2 RemoteViews widget and cold/warm navigation.
- [x] Android settings, source/account mapping and debug parser.
- [x] Native tests, Flutter tests/analyze and APK build.
- [x] Samsung cold startup check via widget intent: Pending screen visible.
- [ ] Real bank notification delivery and Samsung home-screen widget placement (manual acceptance).
- [x] README and limitations.

Decisions: use Room separately from Drift; no new cloud tables. Native capture is
opt-in per signed-in user, stops on logout and wipes private drafts/mappings on
owner change. Completed drafts retain only a fingerprint tombstone to deduplicate
callbacks, with sensitive payload erased. Deterministic canonical UUIDs include
the finance user and fingerprint; a local atomic import receipt makes retry after
partial confirmation safe. No migration is needed for the cloud transaction ID.
Widget uses Android RemoteViews to avoid a Compose dependency. Raw notification text is processed in memory only; Room retains parsed suggestions until review; only user-reviewed normalized
fields enter the existing transaction repository. No network code in native inbox.


Verification (2026-09-14):
- 14 Kotlin/Robolectric tests: 9 parser, 2 Room/registry, 2 listener/extractor,
  1 widget count + click intent; all passed, zero skipped.
- 56 finance_core Flutter tests passed, including local commit/native-finish retry,
  immediate pending refresh, Vietnamese narrow layout, cold/warm widget routes, signed-out startup cleanup lifecycle.
- flutter analyze: finance_core, Android launcher, Linux launcher clean.
- flutter test: both launchers passed (1 test each).
- Android debug APK build succeeded. Release signing/build not attempted.
- No Supabase schema or production data modified by this feature.

Sources used for Android integration:
- [NotificationListenerService API](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
- [Room releases](https://developer.android.com/jetpack/androidx/releases/room)
- [Native app widgets](https://developer.android.com/develop/ui/views/appwidgets)
- [KSP 2.3.12](https://github.com/google/ksp/releases/tag/2.3.12)

Important limitations: force-stop/OEM restrictions are outside service control;
no notification history replay; generic VietinBank/BIDV support needs real samples;
missing reference/time implies heuristic deduplication. Real bank delivery and
Samsung launcher widget placement remain manual acceptance tests. The repository
keeps no raw notification fixture beyond the user-provided parser examples.


## Files and integration map

New native files under
`android/android/app/src/main/kotlin/app/personalfinance/finance_android/banknotification/`:

- `BankNotificationListenerService.kt`: system-bound listener; filter before extras;
  executor serializes parsing/storage against owner/config changes. No Flutter engine required.
- `NotificationExtractor.kt`: title/text/bigText/subText/textLines, bounded and deduplicated.
- `BankSourceRegistry.kt`: three verified package IDs; per-source switches/configuration.
- `parser/ParsedBankTransaction.kt`: typed direction/status, normalization and SHA-256 fingerprint.
- `parser/BankMoney.kt`: strict VND/USD grouping and exact integer minor units.
- `parser/BankNotificationParser.kt`: common conservative rules, MB card/account samples,
  MB/VietinBank/BIDV parser extension classes and router. Failure detection runs first.
- `database/BankDraftDatabase.kt`: Room entity/DAO/database version 1 and indexed inbox.
- `BankInbox.kt`: native persistence and owner/privacy lifecycle.
- `bridge/BankDraftFlutterBridge.kt`: owner-scoped MethodChannel calls, notification settings,
  debug-only parse preview, native change events and widget launch request.
- `BankInboxWidget.kt`: RemoteViews count/read intent independent of Dart.

New Android resources: `res/layout/bank_inbox_widget.xml`,
`res/xml/bank_inbox_widget.xml`, `res/drawable/inbox_background.xml`.
Room exported schema: `android/android/app/schemas/...BankDraftDatabase/1.json`.
Native tests: `ParserTest.kt`, `InboxTest.kt`, `ListenerTest.kt`, `WidgetTest.kt`.

New Flutter files under `linux/packages/finance_core/lib/features/bank_import/`:

- `bank_draft.dart`: typed local draft and normalized canonical record mapping.
- `bank_draft_repository.dart`: MethodChannel adapter; Linux does not invoke native methods.
- `bank_confirmation.dart`: owner/id checks before existing repository save.
- `bank_providers.dart`: event-driven count/settings/paginated pending providers.
- `pending_bank_screen.dart`: review/ignore, paging, account mapping and error states.
- `bank_import_settings.dart`: opt-in, access status, bank switches/default accounts, debug parser.

Modified native files: app `build.gradle.kts` (Room/KSP/tests/desugaring),
`AndroidManifest.xml` (permission-bound service and widget receiver),
`MainActivity.kt` (bridge lifecycle and warm widget intents).

Modified shared Flutter files: `app.dart`, `providers.dart`, `router.dart`,
`settings.dart`, `language.dart`, `translations.dart`, `transaction_form.dart`,
`finance_repository.dart`, `local_database.dart`. Existing transaction form is reused;
optional import receipt extends existing atomic SQLite/outbox writes.
New Dart tests: `bank_import_test.dart`, `bank_widget_test.dart`.
Documentation: root `README.md` and this report. No Supabase migration was created;
existing RLS and cloud tables are unchanged. No database admin credentials were read.

## Commands executed

```bash
(cd android/android && ./gradlew :app:testDebugUnitTest)
(cd linux/packages/finance_core && flutter test && flutter analyze)
(cd android && flutter analyze && flutter test)
(cd linux && flutter analyze && flutter test)
python3 linux/tool/flutter_client.py android build apk --debug
adb -s R5CW32L96TB install -r android/build/app/outputs/flutter-apk/app-debug.apk
```

Native tests use real SQLite/Room under Robolectric with synthetic/user-provided
samples; they are not proof of delivery from the installed banking applications.
Flutter tests simulate the platform bridge and offline remote store, checking actual
Drift writes/outbox behavior. Live notification access is never granted programmatically.


Device smoke check: APK updated successfully on Samsung SM A546E (`R5CW32L96TB`).
`adb shell am start -W -n app.personalfinance.finance_android/.MainActivity -a
app.personalfinance.OPEN_BANK_INBOX` returned `Status: ok`, `LaunchState: COLD`.
Filtered UI hierarchy confirmed “Giao dịch chờ duyệt” and “Đã xử lý hết”, verifying
native bridge/Room reads and the actual Flutter pending route on-device. No
Notification Access permission was granted by tooling, and no real bank notification
was injected or financial record created during this check.


Live MB check requested by the user: local native settings showed capture enabled,
MB enabled and an owner present, but Android Notification Access disabled. Room had
no drafts, including no +5,000 VND MB draft. Opened Android's notification-listener
settings for the user to grant access explicitly. This verifies the reason for the
missing draft, not successful live-bank delivery. Previous notifications are not
replayed automatically. No raw notification history was read.


The user then enabled Notification Access manually. A second device check confirmed
access=true, capture=true, MB=true, owner present, and an empty inbox. The earlier
+5,000 VND notification predates access and was not imported. Future live MB
notifications still need to be observed to verify real delivery end-to-end.

Final device update: installed the APK containing the oversized-notification guard
successfully. Android reported the notification listener as a bound/running
`ServiceRecord` in the app process. Re-opening via the widget intent returned
`Status: ok` / `LaunchState: WARM`. After the update, Notification Access, capture,
and MB source remained enabled; native inbox was still empty. No live notification
received after permission activation has yet been verified.
