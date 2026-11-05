# Verification evidence — 2026-10-04

Host: Mac mini M1, 8 GB RAM, macOS 15.5, Xcode 16.4. Runtime: iOS 18.6.

## Verified

- PostgreSQL 17 isolated cluster: `127.0.0.1:5433`, database `qlt_test`; migrations 001–005 applied.
- Native NATS 2.15.0: `127.0.0.1:4222`, isolated `/tmp/qlt-codex-nats` file store.
- Backend: `uv run pytest tests -q` — 55 passed, one upstream deprecation warning.
- API client: 4 passed; finance core: 79 passed; user app: 1 passed. All three Flutter analyses were clean.
- iOS Simulator build succeeded with `API_BASE_URL=http://127.0.0.1:8000/v1`.
- Built app embeds `PlugIns/InboxWidgetExtension.appex`.
- Widget/deep-link XCTest on iPhone 13 / iOS 18.6: 4 passed.
- iPhone 13 notch Simulator `B88E153C-A6A8-4E54-94F3-73B69C6052C0`: launch succeeds after the native lifecycle fix; inspected in light, dark and accessibility-large text. WidgetKit logs confirmed small/medium placeholder generation.

## Screenshots

- `screenshots/iphone13-login-before.png`: pre-fix result returned to Home Screen after launch crash.
- `screenshots/iphone13-login-after-crash-fix.png`: running login UI after lifecycle repair.
- `screenshots/iphone13-login-dark-large.png`: dark theme with accessibility-extra-large text.

## Not completed / exact blockers

- Dynamic Island: task-created iPhone 15 / iOS 18.6 `C2B6C7A8-92B6-4D45-88D6-9226DD6CE0F5` booted, but `simctl install` repeatedly stalled indefinitely without an `installd` diagnostic, after erase and CoreSimulator restarts. An installed-app screenshot was therefore not obtained.
- Authenticated UI tap-through and keyboard testing: this session lacks macOS Accessibility control for Simulator, and the repository has no integration-test UI driver. Static/widget tests are not represented as interactive proof.
- Actual APNs/FCM, physical-device App Group sharing, OS background scheduling, and Android bank capture require provider credentials or devices and were not claimed.
- Repository-wide backend Ruff currently reports 92 pre-existing import-order/unused-import findings. Functional backend tests pass; these unrelated findings were not bulk-reformatted.
