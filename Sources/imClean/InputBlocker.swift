import CoreGraphics
import Foundation

/// Swallows all keyboard, mouse and trackpad events via a HID-level event tap.
/// Esc (keyCode 53) is also swallowed, but its down/up transitions are reported
/// so the caller can implement a hold-to-unlock gesture.
@MainActor
final class InputBlocker {
    static let escKeyCode: Int64 = 53

    var onEscDown: (() -> Void)?
    var onEscUp: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    /// Event types produced by keyboards, mice and trackpads.
    private static let blockedTypes: [UInt32] = [
        1, 2, 3, 4, 5, 6, 7,     // left/right mouse down/up, moved, dragged
        10, 11, 12,              // keyDown, keyUp, flagsChanged
        14,                      // NSSystemDefined (media, brightness, volume keys)
        18, 19, 20,              // rotate, beginGesture, endGesture
        22, 23, 24,              // scrollWheel, tabletPointer, tabletProximity
        25, 26, 27,              // other mouse down/up/dragged
        29, 30, 31, 32,          // gesture, magnify, swipe, smartMagnify
        34,                      // pressure (Force Touch)
        37, 38,                  // directTouch, changeMode
    ]

    private static var eventMask: CGEventMask {
        blockedTypes.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1) }
    }

    /// Returns false if the tap could not be created (usually missing Accessibility permission).
    func start() -> Bool {
        guard tap == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let blocker = Unmanaged<InputBlocker>.fromOpaque(refcon).takeUnretainedValue()
            // The tap source is added to the main run loop, so this runs on the main thread.
            let pass = MainActor.assumeIsolated { blocker.handle(type: type, event: event) }
            return pass ? Unmanaged.passUnretained(event) : nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.runLoopSource = nil
    }

    /// Returns true if the event should pass through.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        case .keyDown, .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.escKeyCode {
                if type == .keyUp {
                    onEscUp?()
                } else if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    onEscDown?()
                }
            }
            return false
        default:
            return false
        }
    }
}
