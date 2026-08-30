import AppKit

/// Borderless screensaver window for Sleepy Mode. Any key or click asks to
/// leave; the controller wires `onExit` to `requestExit()`, which wakes
/// immediately or prompts for Touch ID depending on the "Require Touch ID to
/// exit" setting.
final class SleepyOverlayWindow: NSWindow {
    /// Invoked on any key/click to *request* dismissal. Whether that actually
    /// tears the scene down is the controller's call, not this window's.
    var onExit: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) { onExit?() }
    override func mouseDown(with event: NSEvent) { onExit?() }
    override func rightMouseDown(with event: NSEvent) { onExit?() }

    /// AppKit resolves command-key menu equivalents (Cmd-Q/Cmd-W/Cmd-H, …)
    /// before `keyDown`. Consume those here so they route through the same exit
    /// request instead of quitting/hiding/closing cmux behind the cover. This
    /// also means that while the Touch ID gate is armed, Cmd-Q prompts rather
    /// than quitting out from under the scene.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onExit?()
        return true
    }
}
