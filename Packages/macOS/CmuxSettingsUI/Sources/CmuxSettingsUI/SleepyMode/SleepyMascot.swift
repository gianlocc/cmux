import Foundation

/// Which mascot/face the Sleepy Mode scene draws.
public enum SleepyMascot: String, CaseIterable, Identifiable, Sendable {
    /// The cmux mascot.
    case cmux
    /// A sleepy cat.
    case cat
    /// A friendly ghost.
    case ghost
    /// The Exa "E/X" monogram.
    case exa
    /// A face built from the cmux `>` chevron logo.
    case logoFace

    /// Stable identity for `Identifiable` (the raw string value).
    public var id: String { rawValue }

    /// Whether the scene paints the shared face anchors — blinking eyes, blush,
    /// mouth — on top of this mascot.
    ///
    /// The anchors are fixed grid coordinates chosen for a round head. Logo
    /// marks are line art, so a face lands on the strokes and reads as noise;
    /// they opt out and are drawn as the mark alone.
    public var wearsSharedFace: Bool {
        switch self {
        case .cmux, .cat, .ghost:
            return true
        case .exa, .logoFace:
            return false
        }
    }
}
