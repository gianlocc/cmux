import Foundation
import Testing
@testable import CmuxSettingsUI

@MainActor
@Suite("Sleepy Mode settings")
struct SleepyModeSettingsTests {
    /// Raw values are the persisted representation; renaming one silently resets
    /// everybody's saved mascot to the default.
    @Test func bunnyMascotPersistsUnderAStableRawValue() {
        #expect(SleepyMascot.bunny.rawValue == "bunny")
        #expect(SleepyMascot(rawValue: "bunny") == .bunny)
        #expect(SleepyMascot.allCases.contains(.bunny))

        let defaults = isolatedDefaults()
        SleepyModeSettingsStore(defaults: defaults).mascot = .bunny
        #expect(SleepyModeSettingsStore(defaults: defaults).mascot == .bunny)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "SleepyModeSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
