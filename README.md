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
