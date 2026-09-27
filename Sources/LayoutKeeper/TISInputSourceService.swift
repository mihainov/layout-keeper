import Carbon
import Foundation
import os

/// `InputSourceService` backed by the HIToolbox Text Input Sources (TIS) API.
final class TISInputSourceService: InputSourceService {
    private let log = Logger(subsystem: "dev.local.LayoutKeeper", category: "InputSource")

    func allSelectableKeyboardSources() -> [InputSource] {
        selectableSources().compactMap(Self.makeInputSource)
    }

    func current() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.makeInputSource(source)
    }

    @discardableResult
    func select(id: String) -> Bool {
        guard let source = selectableSources().first(where: { Self.stringProperty($0, kTISPropertyInputSourceID) == id }) else {
            log.error("select: input source not found: \(id, privacy: .public)")
            return false
        }
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            log.error("select: TISSelectInputSource(\(id, privacy: .public)) failed with \(status)")
            return false
        }
        return true
    }

    // MARK: - Private

    private func selectableSources() -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else { return [] }
        return (list as NSArray).map { $0 as! TISInputSource }
    }

    private static func makeInputSource(_ source: TISInputSource) -> InputSource? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else { return nil }
        let name = stringProperty(source, kTISPropertyLocalizedName) ?? id
        return InputSource(id: id, name: name, languageCode: firstLanguage(source))
    }

    private static func firstLanguage(_ source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String]
        return languages?.first
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
