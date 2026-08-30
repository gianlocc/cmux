import Foundation
import LocalAuthentication

/// `LocalAuthentication`-backed unlock gate for Sleepy Mode.
///
/// Uses `.deviceOwnerAuthentication` rather than
/// `.deviceOwnerAuthenticationWithBiometrics`: it tries Touch ID (or an
/// unlocked Apple Watch) first and falls back to the account password, so the
/// gate still works on a Mac with no Touch Bar / Touch ID sensor and after
/// biometry lockout.
///
/// Each attempt builds a fresh `LAContext`. Reusing one would let a prior
/// success satisfy a later prompt within `touchIDAuthenticationAllowableReuseDuration`,
/// which is exactly what a screen lock must not do.
struct SleepyUnlockAuthenticator: SleepyUnlockAuthenticating {
    func authenticate(reason: String) async -> SleepyUnlockOutcome {
        let context = LAContext()
        var canEvaluateError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &canEvaluateError) else {
            return .unavailable
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .authenticated : .denied
        } catch {
            return Self.outcome(for: error)
        }
    }

    /// Maps an `evaluatePolicy` error to an outcome. Only errors that mean "no
    /// prompt could be shown" fail open; everything the user could have
    /// answered (cancel, wrong password, failed match) keeps the scene locked.
    static func outcome(for error: any Error) -> SleepyUnlockOutcome {
        guard let code = (error as? LAError)?.code else { return .denied }
        switch code {
        case .passcodeNotSet, .notInteractive, .invalidContext:
            return .unavailable
        default:
            return .denied
        }
    }
}
