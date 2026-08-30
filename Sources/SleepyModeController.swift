import AppKit
import CmuxSettingsUI
import IOKit.pwr_mgt
import SwiftUI

/// Owns "Sleepy Mode": a cute full-screen keep-awake screensaver. It holds
/// IOKit power assertions so the Mac (and its display) stay awake — useful for
/// leaving the Mac running for the cmux iOS app — and covers every screen with
/// the animated scene.
///
/// By default any key or click wakes it. Turning on "Require Touch ID to exit"
/// routes every wake attempt through `requestExit()`, which demands device-owner
/// authentication (Touch ID, with the account password as fallback) first.
///
/// Even then it is NOT a security boundary: a normal macOS app cannot make an
/// unbypassable lock (force-quitting cmux, or connecting remotely, still reaches
/// the desktop). The gate raises the bar against a passer-by, nothing more. For
/// real security, the scene's "Lock Mac" button triggers the actual macOS login
/// lock.
@MainActor
final class SleepyModeController {
    // App-lifecycle UI/window controller: it owns NSWindows and IOKit power
    // assertions tied to the app's foreground lifetime, so a process-wide
    // instance is the right ownership boundary. This matches the established
    // cmux pattern for such controllers (TerminalController.shared,
    // TaskManagerWindowController.shared, SystemWideHotkeyController.shared,
    // AboutWindowController.shared, and the *WindowController singletons). Its
    // data/service dependencies — the settings store and the power-action
    // service — are NOT baked in here; they are owned as injectable properties
    // below and passed into the scene, which is where the testability boundary
    // belongs.
    static let shared = SleepyModeController()

    /// The single Sleepy Mode settings store, owned here (the app composition
    /// root) and injected into the overlay scene and the Preferences section.
    let store = SleepyModeSettingsStore()

    /// Power-action service (display sleep / real Mac lock / Low Power), owned
    /// here and injected into the scene; swap the runner for tests.
    let powerControls: any SleepyPowerControlling = SleepyPowerControls()

    /// Frame-sampled data providers, owned here and injected into the scene so
    /// the renderer reads instances instead of global singletons.
    let agentCensus: any SleepyAgentCensusing = SleepyAgentCensus()
    let statusProvider: any SleepyStatusProviding = SleepyStatusProvider()

    /// Shared Low Power UI state, so every per-display overlay shows the same
    /// label and toggles from one authoritative value.
    let powerUIState = SleepyPowerUIState()

    /// Device-owner authentication gate used when `store.requireAuth` is on,
    /// owned here and injected into `requestExit()`; swap it for tests.
    let unlockAuthenticator: any SleepyUnlockAuthenticating = SleepyUnlockAuthenticator()

    /// Shared unlock UI state, so every per-display overlay shows one lock hint
    /// and overlapping wake attempts coalesce into a single prompt.
    let lockUIState = SleepyLockUIState()

    private(set) var isActive = false

    /// Invoked whenever sleepy mode turns on or off so menu UI can refresh.
    var onStateChange: (() -> Void)?

    private var overlayWindows: [SleepyOverlayWindow] = []
    private var screenObserver: NSObjectProtocol?

    private var systemAssertionID = IOPMAssertionID(0)
    private var displayAssertionID = IOPMAssertionID(0)
    private var hasSystemAssertion = false
    private var hasDisplayAssertion = false

    private init() {}

    var isHoldingPowerAssertions: Bool { hasSystemAssertion || hasDisplayAssertion }

    /// True only when BOTH keep-awake assertions are held (system idle sleep and
    /// display sleep). Drives the honest on-screen badge — if either failed, the
    /// UI must not claim the Mac is safely staying awake.
    var keepAwakeFullyActive: Bool { hasSystemAssertion && hasDisplayAssertion }

    /// The one shared entry point every user-facing surface flips Sleepy Mode
    /// through (menu bar item, command palette, debug socket `toggle`). Exiting
    /// goes via `requestExit()` so the Touch ID gate applies identically no
    /// matter which surface asked.
    func toggle() {
        if isActive { requestExit() } else { activate() }
    }

    /// Shows the screensaver and keeps the Mac awake. Any key/click wakes it,
    /// unless "Require Touch ID to exit" is on — see `requestExit()`.
    func activate() {
        guard !isActive else { return }
        isActive = true
        lockUIState.isPrompting = false
        lockUIState.wasDenied = false
        beginPowerAssertions()
        installScreenObserver()
        rebuildOverlayWindows()
        NSApp.unhide(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        onStateChange?()
    }

    /// Same thing — kept as a distinct entry point for the settings "Preview"
    /// button now that there is no lock distinction.
    func preview() {
        activate()
    }

    /// The user-facing way out of Sleepy Mode: the overlay's key/click handlers
    /// and the scene's Exit button all go through here.
    ///
    /// With "Require Touch ID to exit" off this is plain `deactivate()`. With it
    /// on, the scene stays up until device-owner authentication succeeds.
    ///
    /// `deactivate()` itself stays ungated on purpose — it is the escape hatch
    /// the debug socket's `sleepy_mode off` uses, so a prompt that cannot be
    /// shown or dismissed can never strand the user behind a full-screen
    /// overlay.
    func requestExit() {
        guard isActive else { return }
        guard store.requireAuth else {
            deactivate()
            return
        }
        // One prompt at a time: there is one overlay per display, and a
        // held-down key repeats its `keyDown`.
        guard !lockUIState.isPrompting else { return }
        lockUIState.isPrompting = true
        lockUIState.wasDenied = false
        let authenticator = unlockAuthenticator
        let reason = String(localized: "sleepyMode.unlockReason", defaultValue: "Unlock cmux Sleepy Mode")
        Task { [self] in
            let outcome = await authenticator.authenticate(reason: reason)
            lockUIState.isPrompting = false
            if outcome == .unavailable {
                cmuxDebugLog("sleepyMode.unlock unavailable — exiting without authentication")
            }
            switch SleepyUnlockDecision(outcome) {
            case .exit:
                deactivate()
            case .stayLocked:
                lockUIState.wasDenied = true
            }
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        lockUIState.isPrompting = false
        lockUIState.wasDenied = false
        removeScreenObserver()
        endPowerAssertions()
        tearDownOverlayWindows()
        onStateChange?()
    }

    // MARK: - Overlay windows

    private func rebuildOverlayWindows() {
        tearDownOverlayWindows()
        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        for screen in screens {
            let window = makeOverlayWindow(for: screen)
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
    }

    private func makeOverlayWindow(for screen: NSScreen) -> SleepyOverlayWindow {
        let window = SleepyOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("cmux.sleepyMode")
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.acceptsMouseMovedEvents = true
        window.setFrame(screen.frame, display: true)
        window.onExit = { [weak self] in self?.requestExit() }
        window.contentView = NSHostingView(rootView: SleepyFaceView(store: store, power: powerControls, keepingAwake: keepAwakeFullyActive, agentCensus: agentCensus, statusProvider: statusProvider, powerUIState: powerUIState, lockUIState: lockUIState))
        return window
    }

    private func tearDownOverlayWindows() {
        for window in overlayWindows {
            window.onExit = nil
            window.contentView = nil
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }

    private func installScreenObserver() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.rebuildOverlayWindows()
            }
        }
    }

    private func removeScreenObserver() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    // MARK: - Power assertions

    /// In-process equivalent of `caffeinate -d -i`: keep the display awake so the
    /// screensaver stays visible, and stop the system from idle-sleeping.
    private func beginPowerAssertions() {
        let reason = "cmux Sleepy Mode" as CFString
        if !hasSystemAssertion {
            var id = IOPMAssertionID(0)
            if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &id) == kIOReturnSuccess {
                systemAssertionID = id
                hasSystemAssertion = true
            }
        }
        if !hasDisplayAssertion {
            var id = IOPMAssertionID(0)
            if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &id) == kIOReturnSuccess {
                displayAssertionID = id
                hasDisplayAssertion = true
            }
        }
    }

    private func endPowerAssertions() {
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
            systemAssertionID = IOPMAssertionID(0)
        }
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
            displayAssertionID = IOPMAssertionID(0)
        }
    }
}
