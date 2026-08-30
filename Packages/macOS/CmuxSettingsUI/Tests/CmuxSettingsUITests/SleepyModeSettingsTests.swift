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
    @Test func exaMascotPersistsUnderAStableRawValue() {
        #expect(SleepyMascot.exa.rawValue == "exa")
        #expect(SleepyMascot(rawValue: "exa") == .exa)
        #expect(SleepyMascot.allCases.contains(.exa))

        let defaults = isolatedDefaults()
        SleepyModeSettingsStore(defaults: defaults).mascot = .exa
        #expect(SleepyModeSettingsStore(defaults: defaults).mascot == .exa)
    }

    /// The cmux chevron has always been drawn; anyone upgrading keeps it unless
    /// they turn it off themselves.
    @Test func cmuxLogoStaysOnByDefaultAndPersists() {
        #expect(SleepyModeConfig().showLogo)

        let defaults = isolatedDefaults()
        #expect(SleepyModeSettingsStore(defaults: defaults).showLogo)
        SleepyModeSettingsStore(defaults: defaults).showLogo = false

        let reloaded = SleepyModeSettingsStore(defaults: defaults)
        #expect(reloaded.showLogo == false)
        #expect(reloaded.snapshot().showLogo == false)
    }

    /// Every persisted key is a migration surface: renaming one silently resets
    /// that preference for everybody who already set it.
    @Test func persistedKeysAreStable() {
        #expect(SleepyModeDefaultsKeys.requireAuth == "sleepyMode.requireAuth")
        #expect(SleepyModeDefaultsKeys.showLogo == "sleepyMode.showLogo")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "SleepyModeSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
