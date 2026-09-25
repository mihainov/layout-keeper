# LayoutKeeper — Implementation Plan

A minimal macOS menu bar app that remembers the keyboard layout (input source) used in each app and restores it automatically when that app is activated.

> Working name: **LayoutKeeper**. Rename freely.

---

## 1. Goals & Non-Goals

### Goals
1. **Per-app memory:** automatically learn and restore the last layout used in each app.
2. **Fixed per-app rules:** pin a layout to an app (e.g. Terminal → English). Rules override memory.
3. **Default for new apps:** an optional layout to use for apps with no memory or rule.
4. **Menu bar icon:** pause/resume toggle, quick actions, and a view of the current state.
5. **Launch at login** via `SMAppService`.
6. **Ignore list:** apps the switcher never touches.
7. **On-screen indicator (HUD):** a short, non-focus-stealing overlay showing the new layout after an automatic switch.
9. **JSON config** in Application Support: human-readable and dotfile-friendly.

### Non-Goals (explicitly out of scope)
- Per-window/per-tab memory
- Per-website browser rules
- Keystroke interception or remapping (symbols are handled by a custom Ukelele layout — see Appendix A)
- Global hotkeys
- A settings window (config is edited as JSON, plus menu bar quick actions)
- Auto-updates, telemetry, analytics, crash reporting

---

## 2. Security Constraints (hard requirements)

- **No network code at all.** No `URLSession`, no Sparkle, no third-party SDKs.
- **No Accessibility or Input Monitoring permission.** Do not use `CGEventTap`, `AXUIElement` or `IOHIDManager`.
- **No third-party runtime dependencies.** Apple frameworks only: AppKit, SwiftUI, Carbon (HIToolbox TIS APIs), ServiceManagement.
- **Hardened Runtime** enabled.
- **App Sandbox:** try it enabled with **no** `com.apple.security.network.*` entitlements, so the OS enforces "no network". If `TISSelectInputSource` fails silently under the sandbox (verify in M1), disable the sandbox and document it in the README. The no-network rule still holds at the code level.
- **Signing:** personal team (free Apple ID) or "Sign to Run Locally". Built locally only.

---

## 3. Tech Stack

| Item | Choice |
|---|---|
| Language | Swift 5.9+ (latest Xcode) |
| Min macOS | 13 Ventura (needed for `MenuBarExtra` and `SMAppService`) |
| UI | SwiftUI `MenuBarExtra` + an AppKit `NSPanel` for the HUD |
| App type | Agent app: `LSUIElement = YES` (no Dock icon) |
| Project | Xcode project, optionally generated with **XcodeGen** (`project.yml`) so it stays text-based |
| Build | `xcodebuild` from the CLI, plus a `Makefile` with `build`, `run`, `install` (copy to `/Applications`) and `test` |

---

## 4. Architecture

```
LayoutKeeperApp (SwiftUI App, MenuBarExtra)
│
├── AppMonitor            → observes app activation (NSWorkspace)
├── InputSourceService    → list / read / select input sources (TIS APIs)
├── SourceChangeMonitor   → observes input source changes (distributed notification)
├── SwitchEngine          → decision logic (pure, unit-testable)
├── ConfigStore           → loads config.json (user-edited)
├── StateStore            → loads/saves state.json (learned memory)
├── HUDController         → non-activating overlay panel
└── LoginItemService      → SMAppService.mainApp wrapper
```

### 4.1 InputSourceService (protocol + TIS implementation)
- `allSelectableKeyboardSources() -> [InputSource]`: use `TISCreateInputSourceList` filtered by `kTISPropertyInputSourceCategory == kTISCategoryKeyboardInputSource` and `kTISPropertyInputSourceIsSelectCapable == true`.
- `current() -> InputSource`: via `TISCopyCurrentKeyboardInputSource`.
- `select(id:) -> Bool`: via `TISSelectInputSource`. Return false if the ID isn't found or the call fails.
- `InputSource` has `id` (`kTISPropertyInputSourceID`, e.g. `com.apple.keylayout.US`) and `name` (`kTISPropertyLocalizedName`).
- **Must support custom layouts**, such as Ukelele IDs like `org.sil.ukelele.keyboardlayout.<name>.<layout>`.
- Define it behind a protocol so it can be mocked in tests.

### 4.2 AppMonitor
- Observe `NSWorkspace.shared.notificationCenter` for `didActivateApplicationNotification`.
- Extract `bundleIdentifier` from `NSWorkspace.applicationUserInfoKey`. Skip nil bundle IDs and LayoutKeeper itself.

### 4.3 SourceChangeMonitor
- Observe `DistributedNotificationCenter` for `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`.
- On change, the frontmost app is `NSWorkspace.shared.frontmostApplication`. Record the current source into memory for that app, unless it is paused, ignored, or LayoutKeeper itself.
- Recording after LayoutKeeper's own switches is harmless, because it stores the same value, so no suppression flag is needed. Keep it simple.

### 4.4 SwitchEngine (pure function, core of unit tests)

```swift
func resolve(bundleID: String, config: Config, state: State) -> Decision
// Decision: .ignore | .switchTo(sourceID) | .learnCurrent
```

Priority order:
1. `config.enabled == false` (paused) → `.ignore`
2. `bundleID` in `config.ignore` → `.ignore`
3. `bundleID` in `config.rules` → `.switchTo(rule)`
4. `bundleID` in `state.memory` → `.switchTo(memory)`
5. `config.defaultSourceID != nil` → `.switchTo(default)`
6. Otherwise → `.learnCurrent` (store the current source as this app's memory)

Execution rules:
- Skip `select` if the target equals the current source (no-op, no HUD).
- If the target ID no longer exists (layout removed), log it, drop that memory entry, and fall through to the default.

### 4.5 ConfigStore / StateStore
- Location: `~/Library/Application Support/LayoutKeeper/`. Under the sandbox this is `~/Library/Containers/<bundle-id>/Data/Library/Application Support/LayoutKeeper/`; document the actual path.
- **config.json** is user-edited and never written by the app, except through menu quick actions.
- **state.json** is app-written and holds learned memory. Keeping it separate means the config stays clean for dotfiles.
- Write atomically. Debounce state writes (~2 s) and flush on quit.
- On a malformed config: keep the last good config, show an error in the menu, and don't crash.
- Reload via a menu action. Watching the file for changes is optional; skip it for v1.

### 4.6 HUDController
- A borderless `NSPanel` with `.nonactivatingPanel` style, `ignoresMouseEvents = true`, `level = .statusBar`, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- Content: the layout's label (from `config.labels` if set, else its localized name) in a rounded, translucent SwiftUI view.
- Position: bottom-center of the screen with the mouse cursor. Visible for ~0.8 s, then fades out.
- Shown **only after automatic switches** (macOS already shows its own indicator for manual switches). Controlled by `config.hud.enabled`.
- **It must never take focus.** Verify that typing in the target app works immediately after a switch.

### 4.7 LoginItemService
- `SMAppService.mainApp.register()` / `.unregister()`, with status read from `.status`.
- Works reliably when the app runs from `/Applications`. Note this in the README; `make install` handles it.

---

## 5. Config Schema

```json
{
  "version": 1,
  "enabled": true,
  "defaultSourceID": "com.apple.keylayout.US",
  "rules": {
    "com.apple.Terminal": "com.apple.keylayout.US",
    "com.microsoft.VSCode": "com.apple.keylayout.US"
  },
  "ignore": [
    "com.apple.Spotlight"
  ],
  "labels": {
    "com.apple.keylayout.US": "EN",
    "com.apple.keylayout.Bulgarian-Phonetic": "БГ"
  },
  "hud": {
    "enabled": true,
    "durationMs": 800
  }
}
```

`state.json`:

```json
{
  "version": 1,
  "memory": {
    "com.tinyspeck.slackmacgap": "com.apple.keylayout.Bulgarian-Phonetic"
  }
}
```

All fields are optional except `version`. Missing fields fall back to defaults.

---

## 6. Menu Bar Contents

- **Icon/title:** the current layout's short label (from `labels`), or an SF Symbol such as `keyboard` when paused.
- **Status line:** "Active" / "Paused", and the frontmost app's name and the rule source that applied (Rule / Memory / Default).
- **Pause / Resume** toggle, which writes `enabled` to config.
- **Pin current layout to "<frontmost app>"**, which adds or updates a rule. (The menu bar extra doesn't activate the app, so "frontmost" is still the user's app. Verify this.)
- **Ignore "<frontmost app>"** / **Stop ignoring**.
- **Forget memory for "<frontmost app>"** and **Forget all memory**.
- **Copy current layout ID**, useful for editing rules, especially for custom Ukelele IDs.
- **Open config folder** (Finder) and **Reload config**.
- **Launch at login** toggle.
- **Quit**.

---

## 7. Milestones

Each milestone should build, run and be committed before starting the next.

| # | Milestone | Done when |
|---|---|---|
| M0 | **Scaffold:** XcodeGen project, agent app, empty `MenuBarExtra`, Makefile, hardened runtime, sandbox on and no network entitlement | App runs with an icon in the menu bar and no Dock icon |
| M1 | **InputSourceService:** list, current, select; debug menu listing all layouts | Can switch layouts from the debug menu. **Sandbox compatibility verified**, and the decision is documented |
| M2 | **Per-app memory + default** (features 1, 3): AppMonitor, SourceChangeMonitor, SwitchEngine, StateStore | Switching between two apps restores each one's last layout, and the memory survives a restart |
| M3 | **Config, rules, ignore list** (features 2, 6, 9): ConfigStore and malformed-config handling | Rules override memory, ignored apps are untouched, and a bad JSON file doesn't crash the app |
| M4 | **Menu bar** (feature 4): all items from §6 | All quick actions work and are reflected in config.json |
| M5 | **Launch at login** (feature 5) | Survives a logout/login when installed in `/Applications` |
| M6 | **HUD** (feature 7) | HUD appears only on automatic switches, never steals focus, and works in full-screen apps and across Spaces |
| M7 | **Hardening:** tests, README, network audit | All checks in §8 pass |

---

## 8. Testing & Verification

### Unit tests (XCTest)
- `SwitchEngine.resolve` covers every branch of the priority order, including paused, ignored, rule vs memory, default, learn-current, and a missing target ID.
- Config decoding covers a full file, a minimal file (`version` only), unknown fields (ignored), and malformed JSON (error).
- StateStore: a save/load round trip.

### Manual checklist
- [ ] App A = BG, App B = EN. ⌘-Tab between them repeatedly and confirm the correct layout each time.
- [ ] Changing the layout via Caps Lock, the menu bar or a shortcut updates memory for the frontmost app.
- [ ] A pinned rule wins even after a manual change in that app, which reverts on the next activation.
- [ ] An app on the ignore list is never switched.
- [ ] A new app gets the default layout, or keeps the current one if no default is set.
- [ ] A custom Ukelele layout works as a rule target.
- [ ] Typing immediately after the HUD appears goes to the app, with no lost keystrokes.
- [ ] Pause stops all switching and learning.
- [ ] Removing a layout from Input Sources doesn't break anything; the stale entry is dropped.

### Security audit (must pass)
- [ ] `grep -rE "URLSession|NSURLConnection|Network\.framework|CGEventTap|AXUIElement|IOHIDManager" Sources/` returns nothing.
- [ ] The entitlements file contains no `network` keys.
- [ ] `codesign -d --entitlements - LayoutKeeper.app` matches what's expected.
- [ ] Optional: run with **LuLu** and confirm zero outbound connection attempts.
- [ ] System Settings → Privacy & Security doesn't list the app under Accessibility or Input Monitoring.

---

## 9. Known Limitations (document in the README)

- System panels such as Spotlight, Raycast/Alfred and some pop-ups don't always fire an app activation. Their layout follows whatever app was active before.
- Memory is per app, not per window. Two Slack workspaces share one layout.
- Rapid ⌘-Tab cycling may briefly flash intermediate layouts. This is acceptable.

---

## Appendix A — Symbol Consistency via Ukelele (manual, no code)

Goal: Shift + number-row symbols (and other punctuation) behave like US English while typing Bulgarian.

1. Install **Ukelele** (free, from SIL).
2. **File → New From Current Input Source** while the Bulgarian layout is active.
3. Remap the Shift + number row (and any other keys) to their US equivalents.
4. Set a unique name and ID, then save as a `.bundle` or `.keylayout` into `~/Library/Keyboard Layouts/`.
5. Log out and back in, add it under **System Settings → Keyboard → Input Sources**, and remove the original Bulgarian layout if you like.
6. Use **Copy current layout ID** in LayoutKeeper to get its ID for rules and labels.