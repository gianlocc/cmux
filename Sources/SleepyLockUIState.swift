import Observation

/// Shared, observable state for the Sleepy Mode unlock gate. Sleepy Mode builds
/// one overlay window per display; injecting a single instance into every
/// `SleepyFaceView` keeps their lock hints in sync and lets the controller
/// coalesce the overlapping unlock attempts a multi-display setup produces.
@MainActor
@Observable
final class SleepyLockUIState {
    /// Whether an authentication sheet is currently up. Also the in-flight
    /// guard: a held-down key must not stack one prompt per repeat.
    var isPrompting = false
    /// Whether the most recent unlock attempt was refused, so the scene says so
    /// instead of silently swallowing the attempt. Cleared when the next prompt
    /// opens and whenever Sleepy Mode starts or stops — never on a deadline,
    /// because the hint renders outside the animating `TimelineView` and a timer
    /// expiring would not invalidate the body.
    var wasDenied = false
}
