# Runbook: iOS Simulator Verification & Widget Testing

This runbook documents the required procedure to build, run native Swift unit tests, deploy to the iOS Simulator, and verify the `quanlytao` User App and its count-only `InboxWidget` extension.

> **Status Notice:** Per project requirements, this document prepares the exact commands and test matrix. Since the local build environment is Linux x86_64, actual iOS compilation and execution are deferred to a macOS host during validation (T23). Keep validation pending until macOS checks actually run; Android success is not iOS verification.

---

## 1. Prerequisites (macOS Host)

- macOS Sonoma (14.x) or macOS Sequoia (15.x)
- Xcode 15.0+ or Xcode 16.0+ with iOS 17/18 Simulator runtime
- Flutter 3.24+ (stable channel)
- CocoaPods (`sudo gem install cocoapods` or `brew install cocoapods`)
- Git repository clone of `personal-management`

---

## 2. Environment Verification

Run from the repository root:

```bash
flutter doctor -v
xcodebuild -version
xcrun simctl list runtimes
```

Ensure no missing toolchain components for iOS development.

---

## 3. Simulator Discovery & Booting

List available iOS Simulator devices:

```bash
xcrun simctl list devices available
```

Pick an iPhone simulator (recommended: `iPhone 16` or `iPhone 15 Pro` running iOS 17+ or 18+):

```bash
# Boot the chosen simulator by name or UDID
xcrun simctl boot "iPhone 16" || true

# Open the Simulator graphical window
open -a Simulator
```

---

## 4. Dependencies & Workspace Setup

Navigate to the user app directory and fetch Flutter / iOS Pod dependencies:

```bash
cd apps/user_app
flutter pub get
cd ios
pod install --repo-update
cd ../../..
```

---

## 5. Native Swift Unit Tests Execution

Run the XCTest suite for `RunnerTests` (including `InboxWidgetTests.swift`):

```bash
xcodebuild test \
  -workspace apps/user_app/ios/Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/InboxWidgetTests
```

### Verified Test Cases:
1. `testWidgetSummaryDecoding`: Validates decoding of `/v1/widget/summary` response (`pending_count`, `pending_ids`, `captured_epoch`).
2. `testWidgetSummaryExcludesFinancialAmounts`: Guarantees no financial amounts (`amount`, `balance`, `money`) are ever present in the widget payload.
3. `testDeepLinkUrlParsing`: Validates `quanlytao://bank-inbox` URL scheme parsing.

---

## 6. Build and Launch User App

Build the iOS Simulator binary with the backend API URL injected via `--dart-define`:

```bash
cd apps/user_app

# Build Simulator bundle
flutter build ios --simulator --dart-define=API_BASE_URL="http://localhost:8000"

# Alternatively, run directly on the booted Simulator:
flutter run -d "iPhone 16" --dart-define=API_BASE_URL="http://localhost:8000"
```

---

## 7. Deep Link Verification

With the app running (or terminated in the background), test the deep link from terminal:

```bash
xcrun simctl openurl booted "quanlytao://bank-inbox"
```

**Expected Result:**
- The app opens immediately and navigates to the **Biến động** (Pending bank transactions) tab (`/pending`).
- If unauthenticated, the app redirects to the Login screen first, and after login transitions directly to `/pending`.

---

## 8. Adding the Widget to Simulator Home Screen

1. On the booted simulator, press `Cmd + Shift + H` to return to the Home Screen.
2. Long-press on an empty area of the home screen until app icons enter jiggle mode.
3. Tap the `+` button in the top-left corner.
4. Search for `User App` or `Quản lý Tao`.
5. Select `Biến động ngân hàng` widget:
   - Preview Small (`systemSmall`) and Medium (`systemMedium`) widgets.
   - Tap **Add Widget**.
6. Tap **Done** to exit edit mode.

---

## 9. Simulator Verification Checklist (T23)

| Check | Steps | Expected Result | Pass/Fail |
|---|---|---|---|
| **Count-only display** | Observe widget on Home Screen | Shows integer pending count and label "giao dịch cần phân loại". **No monetary values (VND/đ), balances, or account numbers.** | Pending macOS |
| **Zero count state** | Classify or discard all pending events | Widget displays `0` and "Không có giao dịch cần phân loại". | Pending macOS |
| **Logged-out state** | Log out from User App Settings | Widget switches to "Chưa đăng nhập - Chạm để mở ứng dụng". | Pending macOS |
| **Deep linking** | Tap widget in any state | Opens app and navigates directly to `/pending`. | Pending macOS |
| **Offline resilience** | Enable Airplane mode / disable network | Widget shows orange indicator dot, retaining last cached count without crashing. | Pending macOS |
| **Light & Dark theme** | Toggle Appearance in iOS Settings | Widget background and typography adapt smoothly between light and dark surfaces. | Pending macOS |
| **Dynamic Type** | Set larger text size in iOS Settings | Widget text scales gracefully with `minimumScaleFactor(0.8)`. | Pending macOS |

---

## 10. Capturing Visual Evidence

Take simulator screenshots for validation artifacts:

```bash
mkdir -p artifacts/ios_screenshots
xcrun simctl io booted screenshot artifacts/ios_screenshots/widget_home_screen.png
xcrun simctl io booted screenshot artifacts/ios_screenshots/pending_screen.png
xcrun simctl io booted screenshot artifacts/ios_screenshots/dark_mode_widget.png
```
