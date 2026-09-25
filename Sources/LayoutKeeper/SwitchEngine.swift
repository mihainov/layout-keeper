import Foundation

/// Pure decision logic: which input source should an app get when it is activated?
enum SwitchEngine {
    enum Reason: String, Equatable {
        case rule = "Rule"
        case memory = "Memory"
        case `default` = "Default"
    }

    enum Decision: Equatable {
        /// Leave the current source alone.
        case ignore
        /// Select this source.
        case switchTo(String, Reason)
        /// Store the current source as this app's memory.
        case learnCurrent
    }

    /// Resolves the decision for `bundleID`. Targets missing from `availableSourceIDs`
    /// (e.g. a removed layout) are skipped so resolution falls through to the next step.
    static func resolve(bundleID: String, config: Config, state: State, availableSourceIDs: Set<String>) -> Decision {
        if !config.enabled { return .ignore }
        if config.ignore.contains(bundleID) { return .ignore }
        if let rule = config.rules[bundleID], availableSourceIDs.contains(rule) {
            return .switchTo(rule, .rule)
        }
        if let memory = state.memory[bundleID], availableSourceIDs.contains(memory) {
            return .switchTo(memory, .memory)
        }
        if let fallback = config.defaultSourceID, availableSourceIDs.contains(fallback) {
            return .switchTo(fallback, .default)
        }
        return .learnCurrent
    }
}
