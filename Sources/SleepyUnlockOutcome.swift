import Foundation

/// Result of one Sleepy Mode unlock attempt.
enum SleepyUnlockOutcome: Equatable, Sendable {
    /// The user proved device ownership (Touch ID, Apple Watch, or the account
    /// password) — Sleepy Mode may exit.
    case authenticated
    /// The user cancelled or failed the prompt — the scene stays up.
    case denied
    /// This Mac cannot present device-owner authentication at all (no password
    /// set, or a non-interactive context). Callers must fail *open* here: the
    /// overlay covers every screen, so refusing to exit when no prompt can be
    /// shown would trap the user with no way back to their desktop.
    case unavailable
}
