import Foundation
import Testing
@testable import CmuxSettingsUI

@MainActor
@Suite("Sleepy Mode settings")
struct SleepyModeSettingsTests {
    /// Sleepy Mode must never come up locked for someone who never asked for it:
    /// the gate is opt-in.
    @Test func unlockGateIsOffByDefault() {
        #expect(SleepyModeConfig().requireAuth == false)
        let store = SleepyModeSettingsStore(defaults: isolatedDefaults())
        #expect(store.requireAuth == false)
        #expect(store.snapshot().requireAuth == false)
    }

    @Test func unlockGateSurvivesRelaunch() {
        let defaults = isolatedDefaults()
        SleepyModeSettingsStore(defaults: defaults).requireAuth = true

        let reloaded = SleepyModeSettingsStore(defaults: defaults)
        #expect(reloaded.requireAuth)
        #expect(reloaded.snapshot().requireAuth)
    }

    /// The renderer reads `snapshot()` fresh every frame, so a change made in
    /// Settings while the overlay is up has to show through immediately.
    @Test func snapshotTracksTheLiveGate() {
        let store = SleepyModeSettingsStore(defaults: isolatedDefaults())
        store.requireAuth = true
        #expect(store.snapshot().requireAuth)
        store.requireAuth = false
        #expect(store.snapshot().requireAuth == false)
    }

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
