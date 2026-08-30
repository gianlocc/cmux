import Foundation

/// What Sleepy Mode does with an unlock attempt's outcome. Kept as its own type
/// so the fail-open rule has exactly one definition, and so that rule can be
/// tested without standing up an overlay window or a Touch ID prompt.
enum SleepyUnlockDecision: Equatable, Sendable {
    /// Tear the overlay down and hand the desktop back.
    case exit
    /// Keep the scene up; the user did not authenticate.
    case stayLocked

    /// `.unavailable` deliberately maps to `.exit`. The overlay covers every
    /// screen, so if this Mac cannot present device-owner authentication at all,
    /// staying locked would leave the user no way back to their desktop. A gate
    /// that can strand you is worse than a gate that yields when it cannot ask.
    init(_ outcome: SleepyUnlockOutcome) {
        switch outcome {
        case .authenticated, .unavailable:
            self = .exit
        case .denied:
            self = .stayLocked
        }
    }
}
