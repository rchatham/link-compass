# LinkCompass — Agent Handoff Plan

## Project summary

Build a native macOS app that acts as the user's default browser, but instead of rendering web pages itself, it intercepts opened `http://` and `https://` links and shows a fast popup chooser for selecting the real browser to open the URL in.

The chooser should remember user preferences so common choices become one-key or automatic over time.

Working name: **LinkCompass**

Repo path:

```text
/Users/reidchatham/Developer/link-compass
```

## Product goals

- Native macOS popup browser chooser.
- Can be set as the system default browser.
- Handles normal link opens from other apps.
- Lets the user choose Safari, DuckDuckGo, Chromium, Chrome, Firefox/Mozilla, Brave, etc.
- Remembers choices.
- Starts simple with explicit preferences/rules.
- Leaves room for future machine-learning-based recommendations.
- Intended for both open source distribution and eventual Mac App Store distribution.

## Initial UX

When a URL is opened:

1. LinkCompass receives the URL as the default browser handler.
2. A small, fast popup appears near the center of the screen.
3. The popup shows:
   - URL/domain being opened.
   - Recommended/default browser highlighted.
   - Installed browsers as selectable rows.
4. Pressing `Enter` opens with the highlighted browser.
5. Arrow keys or number shortcuts select a different browser.
6. Optional checkbox/toggle or shortcut to remember the choice for the current domain.

Suggested default behavior for MVP:

- If there is a saved domain preference, preselect it.
- If no saved domain preference exists, preselect the global default browser.
- Always show the chooser at first.
- Later, add an option to auto-open when a matching rule exists.

## Core MVP features

### 1. Default browser handler

The app must register as a handler for:

- `http`
- `https`

Implementation notes:

- Use native macOS Swift/AppKit.
- Configure app bundle URL/document handling metadata as needed.
- Use Launch Services APIs where appropriate.
- The user may still need to manually set LinkCompass as default browser in System Settings or via an onboarding flow.

### 2. URL receive/open flow

- Receive incoming URLs from macOS.
- Parse the URL.
- Extract normalized domain/host.
- Show popup chooser.
- Open selected browser using `NSWorkspace`.

Likely API direction:

```swift
NSWorkspace.shared.open(
    urls,
    withApplicationAt: browserURL,
    configuration: configuration
)
```

### 3. Browser detection

Detect installed browsers, including at least:

- Safari
- Google Chrome
- Chromium
- Brave Browser
- Firefox
- DuckDuckGo Browser
- Microsoft Edge, if installed

Store browser metadata:

- Display name
- Bundle identifier
- App path
- Icon
- Installed/uninstalled state

Prefer bundle identifiers over hardcoded paths when possible.

### 4. Preferences and memory

For the first version, use simple persisted preferences, not ML.

Suggested model:

```swift
struct BrowserChoiceRule: Codable, Identifiable {
    let id: UUID
    let hostPattern: String
    let browserBundleIdentifier: String
    let createdAt: Date
    let updatedAt: Date
    var usageCount: Int
}
```

Persist with either:

- `UserDefaults` for MVP simplicity, or
- JSON file in Application Support for easier open-source/debuggable config.

Initial preference types:

- Global default browser.
- Per-domain preferred browser.
- Last selected browser per domain.

Future preference types:

- Full URL pattern rules.
- Originating app rules, e.g. Slack links vs Mail links.
- Time/context-based suggestions.
- Browser profile support.

### 5. Popup chooser UI

Use SwiftUI or AppKit. A native SwiftUI app with AppKit integration is acceptable, but confirm URL-handler lifecycle works cleanly.

Popup requirements:

- Very fast to appear.
- Keyboard-first.
- `Enter` opens highlighted recommendation.
- `Esc` cancels/closes.
- Number keys pick browser.
- Clear “remember for this domain” affordance.

### 6. Menu bar utility

Not required for the very first MVP, but design with it in mind.

Future menu bar features:

- Enable/disable chooser.
- Set global default browser.
- Manage domain rules.
- Open preferences.
- Show recent links.
- Reset defaults.

### 7. Sharing / open in another browser

Future feature: make it easy to move a page from one browser to another.

Possible approaches:

- macOS Share Extension so a URL can be shared to LinkCompass.
- Browser extensions for Safari/Chrome/Firefox/Brave that send the current tab URL to LinkCompass.
- Custom URL scheme, e.g. `linkcompass://open?url=...`, used by extensions.
- Native helper endpoint is probably unnecessary for MVP and may complicate App Store review.

### 8. Future ML/recommendation direction

Start with explicit user choices and simple heuristics.

Possible later model inputs:

- Domain.
- URL path/category.
- Browser chosen historically.
- Time of day.
- Source application.
- Work vs personal context.
- Whether user overrode the recommendation.

Do not add ML in MVP. Design data collection carefully and transparently because this app handles URLs, which are sensitive.

Privacy principles:

- Local-only by default.
- No telemetry without explicit opt-in.
- Never upload URL history by default.
- Clear privacy policy before App Store distribution.

## Open source and App Store considerations

- Avoid private macOS APIs.
- Keep entitlements minimal.
- Do not require elevated permissions for MVP.
- Be careful with URL history storage; URLs may contain private tokens.
- Prefer storing domains over full URLs unless needed.
- Provide a privacy-first README.
- Add tests for URL normalization and rule matching.
- Consider app sandboxing early if App Store distribution is a goal.

## Proposed technical stack

- Language: Swift
- UI: SwiftUI with AppKit bridge where needed, or pure AppKit if URL handler/window activation is easier
- Platform: macOS only initially
- Persistence: JSON in Application Support or UserDefaults for MVP
- Tests: XCTest
- Build: Xcode project or Swift Package plus app target

## Suggested repo structure

```text
link-compass/
  AGENT_PLAN.md
  README.md
  LinkCompass.xcodeproj/        # when created
  LinkCompass/
    App/
    BrowserDetection/
    URLHandling/
    Rules/
    ChooserUI/
    Persistence/
  LinkCompassTests/
```

## First implementation milestone

Create a minimal macOS app that:

1. Builds and launches.
2. Can be selected as default browser.
3. Receives `http` and `https` URLs.
4. Shows a popup with installed browsers.
5. Opens the URL in the selected browser.
6. Remembers a global default browser.
7. Lets Enter accept the default.

## Second milestone

Add per-domain memory:

1. Normalize domains.
2. Persist domain-to-browser choices.
3. Preselect remembered browser for known domains.
4. Add “remember this choice for this domain”.
5. Add unit tests for domain normalization and rule matching.

## Third milestone

Add user-facing preferences/menu bar:

1. Menu bar item.
2. Preferences window.
3. Rule list editor.
4. Global default selector.
5. Option to always show chooser vs auto-open matched domains.

## Future milestones

- Browser extensions.
- Share extension.
- Custom URL scheme for opening current tab from browser extensions.
- Browser profile support.
- Import/export rules.
- Local-only recommendation engine.
- Optional synced settings.

## Name ideas considered

Chosen working name: **LinkCompass**

Other possible names:

- BrowserCompass
- LinkPilot
- RouteLink
- LinkRouter
- OpenWith
- TabCompass
- Waypoint
- BrowserSwitchboard

Rationale for LinkCompass:

- Suggests routing/navigation without sounding too technical.
- Works for App Store and open source branding.
- Not tied only to browsers, leaving room for URL routing and sharing features.

Before public release, check:

- GitHub repository name availability.
- App Store name availability.
- Trademark conflicts.
- Existing macOS browser chooser apps with similar names.

## Notes for next agent

- Start by creating the macOS app scaffold.
- Prefer Swift and native macOS APIs.
- Keep MVP small: popup chooser first, menu bar/preferences later.
- Treat URL privacy as a first-class design concern.
- Do not implement ML yet; leave clean event/preference models that could support recommendations later.
