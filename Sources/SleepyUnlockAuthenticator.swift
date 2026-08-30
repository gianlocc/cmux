import Foundation
import LocalAuthentication

/// `LocalAuthentication`-backed unlock gate for Sleepy Mode.
///
/// Uses `.deviceOwnerAuthentication` rather than
/// `.deviceOwnerAuthenticationWithBiometrics`: it tries Touch ID (or an
/// unlocked Apple Watch) first and falls back to the account password, so the
/// gate still works on a Mac with no Touch ID sensor and after biometry lockout.
///
/// Each attempt builds a fresh `LAContext`. Reusing one would let a prior
/// success satisfy a later prompt within `touchIDAuthenticationAllowableReuseDuration`,
/// which is exactly what a screen lock must not do. The live context is retained
/// only so `cancel()` can invalidate it; a reference class (not a struct) is
/// required for that.
@MainActor
final class SleepyUnlockAuthenticator: SleepyUnlockAuthenticating {
    private var activeContext: LAContext?

    func authenticate(reason: String) async -> SleepyUnlockOutcome {
        // Any prompt still standing belongs to a superseded attempt.
        cancel()

        let context = LAContext()
        var canEvaluateError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &canEvaluateError) else {
            return .unavailable
        }
        activeContext = context
        defer { if activeContext === context { activeContext = nil } }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .authenticated : .denied
        } catch {
            return Self.outcome(for: error)
        }
    }

    /// Invalidating the context dismisses the panel and makes the pending
    /// `evaluatePolicy` throw `LAError.appCancel`, so the `await` above always
    /// resumes and the caller's "prompting" state always clears.
    func cancel() {
        activeContext?.invalidate()
        activeContext = nil
    }

    /// Maps an `evaluatePolicy` error to an outcome. Only errors that mean "no
    /// prompt could be shown" fail open; everything the user could have
    /// answered (cancel, wrong password, failed match) keeps the scene locked.
    ///
    /// `nonisolated` because it is a pure mapping — it touches no context and no
    /// UI, and the isolation it would otherwise inherit from the class only
    /// makes it awkward to test.
    nonisolated static func outcome(for error: any Error) -> SleepyUnlockOutcome {
        guard let code = (error as? LAError)?.code else { return .denied }
        switch code {
        case .passcodeNotSet, .notInteractive, .invalidContext:
            return .unavailable
        default:
            return .denied
        }
    }
}
