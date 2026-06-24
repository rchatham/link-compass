# LinkCompass

A native macOS browser chooser that can act as your default browser, remember browser preferences by domain, and route links to Safari, Chrome, Brave, Firefox, DuckDuckGo, Chromium, Edge, and more.

Current status: MVP scaffold. See [`AGENT_PLAN.md`](./AGENT_PLAN.md) for the product plan.

## Build and test

SwiftPM:

```bash
swift test
swift build -c release --product LinkCompass
```

Xcode:

```bash
xcodegen generate
xcodebuild -project LinkCompass.xcodeproj -scheme LinkCompass -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

Optional onboarding UI test:

```bash
pkill -x LinkCompass || true
xcodebuild -project LinkCompass.xcodeproj -scheme LinkCompassUITests -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

Current unit tests cover URL normalization, rule persistence, auto-open settings, rule deletion, and chooser keyboard-selection behavior. The UI test verifies the onboarding window and setup actions.

## Build the app bundle

SwiftPM builds the executable; the helper script wraps it in a real `.app` bundle with `http`/`https` URL-handler metadata, ad-hoc signs it, and registers it with Launch Services:

```bash
scripts/make-app.sh
```

The app bundle is created at:

```text
build/LinkCompass.app
```

To install it where macOS is most likely to show it in Default Browser settings:

```bash
scripts/install-app.sh
```

This copies the app to `/Applications/LinkCompass.app` and registers it with Launch Services. By default it uses ad-hoc signing for local development. For a Developer ID build, provide a signing identity:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/install-app.sh
```

Public distribution should also notarize and staple the app.

After installing, open LinkCompass. The setup window includes a **Set Automatically** button and a shortcut to macOS Default Browser settings. You can also set LinkCompass as the default web browser manually in System Settings, then test with:

```bash
open https://example.com
```

For a lightweight automation smoke test that builds the bundle, launches the app, and delivers a URL directly to it:

```bash
scripts/smoke-test.sh
```

## Current app features

- Onboarding/setup window on launch with default-browser status, setup actions, detected browsers, and privacy explanation.
- Menu bar status item with Settings and Quit actions.
- Settings window for global default browser, auto-open known domains, and remembered domain rules.
- Chooser popup with Enter/Esc/arrow/number-key support.
- Optional per-domain remember toggle.
- Optional auto-open for explicit remembered domain rules.

## Privacy note

LinkCompass passes the full URL only to the selected browser. Preferences persist normalized domains and browser bundle identifiers; full URLs, paths, and query strings are not stored.
