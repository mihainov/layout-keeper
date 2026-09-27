# LayoutKeeper

A minimal macOS menu bar app that remembers the keyboard layout used in each app and restores it when that app is activated. See [PLAN.md](PLAN.md) for the full design.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make build             # Release build into ./build
make run               # build and launch
make install           # copy to /Applications and launch
make test              # unit tests
make test-integration  # also runs TIS tests (briefly switches your layout)
```

## App Sandbox

The app runs with the App Sandbox enabled and no `com.apple.security.network.*` entitlements, so the OS blocks all network access.

`TISSelectInputSource` works under the sandbox (verified in M1 on macOS 26 by `make test-integration`, which runs inside the sandboxed host app). The sandbox therefore stays on.

## Configuration

Files live in the sandbox container:

```
~/Library/Containers/dev.local.LayoutKeeper/Data/Library/Application Support/LayoutKeeper/
├── config.json   # you edit this (see config.example.json)
└── state.json    # learned per-app memory, written by the app
```

Use **Open Config Folder** in the menu to get there, and **Reload Config** after editing. Only `version` is required; missing fields use defaults. If `config.json` is malformed, the app keeps the last good config and shows the error at the top of the menu.

Resolution order when an app is activated: paused → ignore list → rule → memory → `defaultSourceID` → keep the current layout and remember it.

## Launch at login

Toggle **Launch at Login** in the menu. It uses `SMAppService.mainApp` and works reliably only when the app runs from `/Applications`, so install with `make install` first. If macOS asks for approval, the menu shows **Allow in Login Items Settings…**, which opens System Settings → General → Login Items.
