# LayoutKeeper

A minimal macOS menu bar app that remembers the keyboard layout (input source) used in each app and restores it automatically when that app is activated. See [PLAN.md](PLAN.md) for the full design.

- **Per-app memory:** learns and restores the last layout used in each app.
- **Rules:** pin a layout to an app (e.g. Terminal → English). Rules override memory.
- **Default layout** for apps with no memory or rule.
- **Ignore list:** apps LayoutKeeper never touches.
- **HUD:** a short, non-focus-stealing overlay after automatic switches.
- **Menu bar:** current layout, pause/resume and quick actions.
- **Launch at login.**
- **JSON config:** human-readable and dotfile-friendly.

Requires macOS 13 or later.

## Build and install

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The Xcode project is generated from `project.yml` and not committed.

```sh
make build             # Release build into ./build
make run               # build and launch
make install           # copy to /Applications and launch
make test              # unit tests
make test-integration  # also runs TIS tests (briefly switches your layout)
make audit             # security audit (see below)
make clean
```

The app is signed with "Sign to Run Locally" (ad-hoc) with the Hardened Runtime enabled.

## Configuration

Files live in the sandbox container:

```
~/Library/Containers/dev.local.LayoutKeeper/Data/Library/Application Support/LayoutKeeper/
├── config.json   # you edit this (see config.example.json)
└── state.json    # learned per-app memory, written by the app
```

Use **Open Config Folder** in the menu to get there, and **Reload Config** after editing. Only `version` is required; missing fields use defaults. If `config.json` is malformed, the app keeps the last good config and shows the error at the top of the menu. Menu quick actions refuse to write to a malformed file.

```json
{
  "version": 1,
  "enabled": true,
  "defaultSourceID": "com.apple.keylayout.ABC",
  "rules": { "com.apple.Terminal": "com.apple.keylayout.ABC" },
  "ignore": [ "com.apple.Spotlight" ],
  "labels": { "com.apple.keylayout.ABC": "EN", "com.apple.keylayout.Bulgarian-Phonetic": "БГ" },
  "hud": { "enabled": true, "durationMs": 800 }
}
```

| Key | Meaning |
|---|---|
| `enabled` | `false` pauses all switching and learning. |
| `defaultSourceID` | Layout for apps with no rule or memory. Without it, a new app keeps the current layout. |
| `rules` | Bundle ID → layout ID. Always applied on activation, even after a manual change. |
| `ignore` | Bundle IDs that are never switched or learned. |
| `labels` | Layout ID → short label for the menu bar and HUD. |
| `hud` | On-screen indicator settings. |

When an app is activated, LayoutKeeper applies the first match: paused → ignore list → rule → memory → `defaultSourceID` → keep the current layout and remember it. Targets that no longer exist are skipped, and stale memory is dropped.

Find a layout ID with **Copy Current Layout ID**. Find an app's bundle ID with `osascript -e 'id of app "Terminal"'`.

Menu quick actions (Pause, Pin, Ignore) rewrite only the keys they change and keep unknown keys. JSON formatting and key order are normalized.

## Menu

The menu bar shows the current layout's short label: the `labels` entry, else the language code (e.g. `EN`, `BG`). A `⏸` suffix means paused. The menu lists all layouts for switching, so it can replace the system Input menu. To hide that one, turn off **Show Input menu in menu bar** in System Settings → Keyboard → Text Input → Edit.

- Layout list with the current one checked.
- Status and the frontmost app with what applies to it (Rule / Memory / Default / Ignored).
- Pause / Resume.
- Pin current layout to the frontmost app, Ignore / Stop ignoring it, Forget its memory, Forget all memory.
- Copy current layout ID, Open config folder, Reload config.
- Launch at login.

## Launch at login

Toggle **Launch at Login** in the menu. It uses `SMAppService.mainApp` and works reliably only when the app runs from `/Applications`, so install with `make install` first. If macOS asks for approval, the menu shows **Allow in Login Items Settings…**, which opens System Settings → General → Login Items.

## On-screen indicator (HUD)

After an automatic switch, a small overlay near the bottom of the screen with the mouse cursor shows the new layout's label (from `labels`, else its name). It is a non-activating panel that ignores the mouse, so it never takes focus. Manual switches don't show it, because macOS already shows its own indicator. Configure it with `hud.enabled` and `hud.durationMs`.

## Security

- No network code. The App Sandbox is enabled with no `com.apple.security.network.*` entitlements, so the OS also blocks network access.
- No Accessibility or Input Monitoring permission. No `CGEventTap`, `AXUIElement` or `IOHIDManager`. Layouts are read and selected with the Text Input Sources (TIS) API, and app switches come from `NSWorkspace` notifications.
- No third-party dependencies: AppKit, SwiftUI, Carbon (HIToolbox) and ServiceManagement only.
- Hardened Runtime is enabled. Release builds don't carry `get-task-allow`.

`TISSelectInputSource` works under the sandbox. This was verified by `make test-integration`, which runs inside the sandboxed host app. The sandbox therefore stays on.

`make audit` checks the sources for forbidden APIs, checks the entitlements file for network keys, and prints the signed entitlements and code-signing flags. For extra assurance, run the app under [LuLu](https://objective-see.org/products/lulu.html) and confirm there are no connection attempts, and check that System Settings → Privacy & Security doesn't list LayoutKeeper under Accessibility or Input Monitoring.

## Known limitations

- System panels such as Spotlight, Raycast/Alfred and some pop-ups don't always fire an app activation. Their layout follows whatever app was active before.
- Memory is per app, not per window. Two Slack workspaces share one layout.
- Rapid ⌘-Tab cycling may briefly flash intermediate layouts.
- macOS sometimes reverts a switch about 15 ms after an app activates. LayoutKeeper checks 150 ms after each switch and re-applies it once, so the layout may flash briefly.
- Third-party app switchers may briefly become the active app while their switcher is shown. Add them to `ignore`.

## Symbol consistency with Ukelele

To make Shift + number-row symbols behave like US English while typing Bulgarian (or another layout), build a custom layout with [Ukelele](https://software.sil.org/ukelele/). See Appendix A in [PLAN.md](PLAN.md). Custom layouts work as rule targets. Use **Copy Current Layout ID** to get the ID, which looks like `org.sil.ukelele.keyboardlayout.<name>.<layout>`.
