import Foundation
import LocalAuthentication
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Sleepy Mode unlock gate")
struct SleepyUnlockGateTests {
    @Test("Proving device ownership leaves Sleepy Mode")
    func authenticatedExits() {
        #expect(SleepyUnlockDecision(.authenticated) == .exit)
    }

    @Test("A cancelled or failed prompt keeps the scene locked")
    func deniedStaysLocked() {
        #expect(SleepyUnlockDecision(.denied) == .stayLocked)
    }

    /// The overlay covers every screen, so a Mac that cannot present the prompt
    /// must not be able to strand the user behind it. Locking this in: flipping
    /// it to `.stayLocked` would make an unusable-prompt machine unrecoverable
    /// except through the debug socket.
    @Test("An unavailable prompt fails open instead of stranding the user")
    func unavailableFailsOpen() {
        #expect(SleepyUnlockDecision(.unavailable) == .exit)
    }

    @Test("Errors the user could have answered keep the scene locked")
    func answerableErrorsAreDenials() {
        let answerable: [LAError.Code] = [
            .userCancel,
            .systemCancel,
            .appCancel,
            .authenticationFailed,
            .userFallback,
            .biometryLockout,
        ]
        for code in answerable {
            let outcome = SleepyUnlockAuthenticator.outcome(for: LAError(code))
            #expect(outcome == .denied, "\(code) should keep Sleepy Mode locked")
            #expect(SleepyUnlockDecision(outcome) == .stayLocked)
        }
    }

    @Test("Errors meaning no prompt could be shown fail open")
    func unpresentableErrorsFailOpen() {
        let unpresentable: [LAError.Code] = [.passcodeNotSet, .notInteractive, .invalidContext]
        for code in unpresentable {
            let outcome = SleepyUnlockAuthenticator.outcome(for: LAError(code))
            #expect(outcome == .unavailable, "\(code) should not trap the user behind the overlay")
            #expect(SleepyUnlockDecision(outcome) == .exit)
        }
    }

    @Test("A non-LocalAuthentication error is treated as a denial, not an escape")
    func unknownErrorsStayLocked() {
        let outcome = SleepyUnlockAuthenticator.outcome(for: CocoaError(.fileNoSuchFile))
        #expect(outcome == .denied)
    }
}
