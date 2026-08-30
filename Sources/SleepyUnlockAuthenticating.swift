import Foundation

/// Device-owner authentication gate for leaving Sleepy Mode. Injected into
/// `SleepyModeController` so tests can drive every outcome without a Touch ID
/// prompt.
@MainActor
protocol SleepyUnlockAuthenticating: Sendable {
    /// Prompts the user, showing `reason` in the system sheet.
    func authenticate(reason: String) async -> SleepyUnlockOutcome
    /// Tears down a prompt that is currently on screen, resolving the pending
    /// `authenticate(reason:)` call as `.denied`.
    ///
    /// This is what keeps the gate from latching. The overlay swallows input
    /// while a prompt is up, so a prompt that never resolves would lock the user
    /// out permanently — which is exactly what happens when the macOS login lock
    /// takes the prompt away mid-evaluation.
    func cancel()
}
