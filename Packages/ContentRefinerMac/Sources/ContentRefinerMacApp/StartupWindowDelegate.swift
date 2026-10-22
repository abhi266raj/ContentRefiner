import AppKit

/// SwiftCrossUI 0.10 shows its window before clearing its first-update flag.
/// AppKit can synchronously resize during that call and re-enter window creation.
@MainActor
final class StartupWindowDelegate: NSObject, NSWindowDelegate {
    private weak var original: (any NSWindowDelegate)?
    private var resizing = false

    func install(on window: NSWindow) {
        guard window.delegate !== self else { return }
        original = window.delegate
        window.delegate = self
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender.isVisible, !resizing else { return frameSize }
        resizing = true
        defer { resizing = false }
        return original?.windowWillResize?(sender, to: frameSize) ?? frameSize
    }

    func windowWillClose(_ notification: Notification) {
        original?.windowWillClose?(notification)
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        original?.windowWillReturnUndoManager?(window)
    }
}
