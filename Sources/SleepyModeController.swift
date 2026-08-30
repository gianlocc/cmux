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
    private var screenLockObserver: NSObjectProtocol?

    /// Bumped for every unlock attempt. A resolved attempt only writes UI state
    /// if it is still the current one, so a cancelled prompt's late resumption
    /// cannot clobber the state of the prompt that replaced it.
    private var unlockGeneration: UInt64 = 0

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
        installScreenLockObserver()
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
        unlockGeneration &+= 1
        let generation = unlockGeneration
        lockUIState.isPrompting = true
        lockUIState.wasDenied = false
        setOverlayLevel(Self.promptWindowLevel)
        let authenticator = unlockAuthenticator
        let reason = String(localized: "sleepyMode.unlockReason", defaultValue: "Unlock cmux Sleepy Mode")
        Task { [self] in
            let outcome = await authenticator.authenticate(reason: reason)
            // A cancelled or superseded attempt must not write state belonging
            // to the attempt that replaced it.
            guard generation == unlockGeneration else { return }
            lockUIState.isPrompting = false
            setOverlayLevel(.screenSaver)
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

    /// Dismisses a prompt that is currently up and returns to the locked scene.
    ///
    /// This is the gate's release valve. The overlay swallows input while a
    /// prompt is up, so anything that leaves `isPrompting` set forever locks the
    /// user out for good — which is what happens when the macOS login lock tears
    /// the panel away mid-evaluation. The scene's Exit button routes here while
    /// prompting, and the screen-lock observer calls it too, so the state can
    /// always be cleared even if `evaluatePolicy` never resumes on its own.
    func cancelUnlockPrompt() {
        guard lockUIState.isPrompting else { return }
        unlockGeneration &+= 1
        unlockAuthenticator.cancel()
        lockUIState.isPrompting = false
        lockUIState.wasDenied = true
        setOverlayLevel(.screenSaver)
    }

    /// Engages the real macOS login lock.
    ///
    /// When the gate is armed Sleepy Mode steps aside first: the login lock is
    /// strictly stronger, and leaving a gated overlay up behind it means
    /// unlocking the Mac drops you straight back into a Touch ID prompt for the
    /// screensaver. Ungated, the scene stays up as the backdrop, which is the
    /// upstream behavior.
    func lockMac() {
        cancelUnlockPrompt()
        let power = powerControls
        if store.requireAuth { deactivate() }
        Task { await power.lockMacNow() }
    }

    /// The LocalAuthentication panel is presented far below `.screenSaver`, so a
    /// full-screen overlay at that level hides it completely: the prompt is up
    /// and waiting, but invisible, and the scene just looks frozen. Drop to a
    /// normal level while prompting — the overlay is still full-screen and
    /// frontmost, so the desktop stays covered — and restore afterwards.
    private static let promptWindowLevel: NSWindow.Level = .normal

    private func setOverlayLevel(_ level: NSWindow.Level) {
        for window in overlayWindows {
            window.level = level
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        unlockGeneration &+= 1
        unlockAuthenticator.cancel()
        lockUIState.isPrompting = false
        lockUIState.wasDenied = false
        removeScreenObserver()
        removeScreenLockObserver()
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

    /// The Mac locking by any route — our own Lock Mac button, a hot corner,
    /// Ctrl-Cmd-Q, the lid closing — takes the authentication panel down without
    /// necessarily resolving `evaluatePolicy`. Clear the prompt state so the
    /// scene is usable again on return instead of latched on "Waiting for
    /// Touch ID".
    private func installScreenLockObserver() {
        guard screenLockObserver == nil else { return }
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cancelUnlockPrompt()
            }
        }
    }

    private func removeScreenLockObserver() {
        if let screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(screenLockObserver)
            self.screenLockObserver = nil
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
