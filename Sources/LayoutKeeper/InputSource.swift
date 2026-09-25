import Foundation

/// A keyboard input source (layout or input method) as seen by the Text Input Sources API.
struct InputSource: Equatable, Hashable, Identifiable {
    /// `kTISPropertyInputSourceID`, e.g. `com.apple.keylayout.US`.
    let id: String
    /// `kTISPropertyLocalizedName`, e.g. "U.S.".
    let name: String
}

/// Lists, reads and selects keyboard input sources. Kept behind a protocol so it can be mocked in tests.
protocol InputSourceService {
    func allSelectableKeyboardSources() -> [InputSource]
    func current() -> InputSource?
    /// Returns false if the ID isn't found or the system call fails.
    @discardableResult
    func select(id: String) -> Bool
}
