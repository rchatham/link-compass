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

Current unit tests cover URL normalization, rule persistence, auto-open settings, rule deletion, chooser keyboard selection, Share command validation/consent/routing, retry intent, and byte-identical persistence for one-time Share overrides. The UI test verifies the onboarding window and setup actions. After `scripts/make-app.sh`, run `scripts/test-share-input.sh` for 44 strict input cases and `scripts/test-share-layout.sh` for 24 offscreen layout states plus overflow scrolling. These checks launch no windows or browsers and write no preferences. Use matching `CONFIGURATION`/`DERIVED_DATA` overrides for custom builds.

## Build the app bundle

The complete macOS 13+ app requires Xcode and XcodeGen (`brew install xcodegen`). SwiftPM builds the standalone executable and tests, **not** the Share extension. This script builds the Xcode app, embeds its Core framework and sandboxed Share extension, and signs nested code inside-out:

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

`make-app.sh` creates `build/LinkCompass.app`: it does **not** install, launch, or change browser preferences. Xcode may automatically register its derived development build with Launch Services during compilation; the script does not explicitly register the packaged app. `CONFIGURATION=Debug`, `BUILD_DIR`, and `DERIVED_DATA` can override build locations/settings.

`install-app.sh` builds/signs, copies the complete app to `/Applications/LinkCompass.app`, and explicitly registers the app and its extension with Launch Services. It does not launch by default; use `LAUNCH_APP=1` to launch after installation. `INSTALL_DIR` overrides the destination. Both scripts default to ad-hoc signing for local development. For a Developer ID build, provide a signing identity:

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

## Open from the macOS Share menu

Install the complete app, then choose **LinkCompass** in another app's Share menu (for example Safari's Share button). If missing, enable LinkCompass in **System Settings → Privacy & Security → Extensions → Sharing** on macOS 13; newer macOS versions place extension controls under **General → Login Items & Extensions → Sharing**. The Share feature does not require LinkCompass to be your default browser.

- Share exactly one item containing an HTTP(S) URL or text whose entire trimmed contents are a URL. One attachment is accepted; macOS text-only items with no attachments use their complete attributed content text. Multiple links, prose containing a link, files, credentials, and non-web schemes are rejected. A URL representation takes precedence; plain text is considered only when no URL representation is offered.
- Click a browser once to open. Use **1–9** for a browser, **↑/↓** to select, **Enter** to open, or **Esc** to cancel. Normal command shortcuts and checkbox-focused keys are left to macOS. Buttons disable while handing off to prevent duplicate submissions; failures stay visible with **Retry**.
- **Remember this choice for [host]** starts unchecked every time. An unchecked explicit pick overrides any saved host rule/global default for this opening only. It does not change rules/defaults, feed learning, or create route-reminder records.
- Checking Remember requests a permanent host rule. Because custom URL commands are unauthenticated, **LinkCompass asks for confirmation before saving**; a rule is saved only after a successful browser launch and confirmation. One-time picks remain one click. Canceling the extension before submission writes nothing.
- **Use saved choice** asks the containing app to use an explicit host rule first, then the global default, otherwise its picker. It ignores the auto-open setting and learned ranking, and never silently substitutes another browser if the chosen browser is unavailable. The Remember checkbox does not affect this action.

The extension is sandboxed with no App Group, network, or preference-access entitlement. It detects installed supported browsers locally and forwards a versioned URL command to the **exact containing LinkCompass app**, not whichever app happens to handle the custom scheme. Preferences remain in the containing app. The Share sheet completes only after macOS reports a successful handoff; browser-launch and saved-choice errors are then handled by LinkCompass.

## Chrome/Chromium route reminder prototype

LinkCompass includes an early Chrome/Chromium Native Messaging prototype that can prompt after a forwarded link:

1. LinkCompass records a short-lived pending route with only the normalized host and selected browser metadata.
2. The Chrome extension checks the local native host when a top-level page finishes loading.
3. If the page matches a recent LinkCompass handoff, the extension asks whether to remember that host/browser route.

Build and install the local native host manifests:

```bash
scripts/install-native-host.sh
```

Then load the unpacked extension from:

```text
Extensions/Chrome
```

After Chrome assigns an extension ID, replace `REPLACE_WITH_UNPACKED_EXTENSION_ID` in the generated Native Messaging manifests under each browser's `NativeMessagingHosts` directory, then reload the extension.

Safari support is deferred. Safari Web Extensions need separate Xcode/app-extension packaging and should be added after the Chrome/Chromium native messaging flow is proven.

## Known limitations

- This is an early MVP scaffold, not a notarized public release build.
- Local development builds may not appear in macOS Default Browser settings even when Launch Services recognizes them.
- Use the onboarding **Set Automatically** button to set LinkCompass as the `http`/`https` handler during development.
- Public distribution should use a Developer ID signed, notarized, and stapled app bundle.

## Privacy note

LinkCompass passes the full URL to the selected browser. For Share requests, the extension also passes it to its exact containing app in a custom URL command; it does not send network requests or read/write the app's preferences. Preferences persist normalized domains and browser bundle identifiers; full URLs, paths, and query strings are not stored. Unchecked one-time Share choices do not train ranking or create Chrome route reminders.

## License

MIT. See [`LICENSE`](./LICENSE).
