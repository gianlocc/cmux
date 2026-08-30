import Foundation

/// Device-owner authentication gate for leaving Sleepy Mode. Injected into
/// `SleepyModeController` so tests can drive every outcome without a Touch ID
/// prompt.
@MainActor
protocol SleepyUnlockAuthenticating: Sendable {
    /// Prompts the user, showing `reason` in the system sheet.
    func authenticate(reason: String) async -> SleepyUnlockOutcome
}
