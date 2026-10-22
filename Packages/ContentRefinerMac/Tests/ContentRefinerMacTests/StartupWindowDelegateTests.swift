import AppKit
import XCTest
@testable import ContentRefinerMacApp

@MainActor
private final class TestWindow: NSWindow {
    var testVisible = false
    override var isVisible: Bool { testVisible }
}
@MainActor
private final class Delegate: NSObject, NSWindowDelegate {
    var resize: (() -> Void)?
    var calls = 0
    func windowWillResize(_ sender: NSWindow, to size: NSSize) -> NSSize {
        calls += 1; resize?(); return size
    }
}
final class StartupWindowDelegateTests: XCTestCase {
    @MainActor func testInitialDisplayDoesNotReenterLayoutAndLaterResizesAreForwardedOnce() {
        let window = TestWindow(contentRect: .init(x: 0, y: 0, width: 900, height: 680), styleMask: [.titled, .resizable], backing: .buffered, defer: true)
        let original = Delegate()
        window.delegate = original
        let guardDelegate = StartupWindowDelegate()
        guardDelegate.install(on: window)
        let size = NSSize(width: 1000, height: 700)
        XCTAssertEqual(guardDelegate.windowWillResize(window, to: size), size)
        XCTAssertEqual(original.calls, 0)
        window.testVisible = true
        original.resize = { _ = guardDelegate.windowWillResize(window, to: size) }
        XCTAssertEqual(guardDelegate.windowWillResize(window, to: size), size)
        XCTAssertEqual(original.calls, 1)
        guardDelegate.install(on: window)
        XCTAssertTrue(window.delegate === guardDelegate)
    }
}
