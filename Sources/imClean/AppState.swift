import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let holdDuration: TimeInterval = 2
    static let autoUnlockAfter: TimeInterval = 5 * 60

    @Published private(set) var isLocked = false
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var holdProgress: Double = 0
    @Published private(set) var remainingSeconds = Int(AppState.autoUnlockAfter)
    @Published var errorMessage: String?

    /// Called when lock state changes so the app delegate can show/hide overlays.
    var onLockChange: ((Bool) -> Void)?

    private let blocker = InputBlocker()
    private var tickTimer: Timer?
    private var trustTimer: Timer?
    private var lockedAt: Date?
    private var escDownAt: Date?

    init() {
        blocker.onEscDown = { [weak self] in self?.escDownAt = Date() }
        blocker.onEscUp = { [weak self] in
            self?.escDownAt = nil
            self?.holdProgress = 0
        }
    }

    func requestAccessibility() {
        // Literal value of kAXTrustedCheckOptionPrompt (the global isn't concurrency-safe in Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        startTrustPolling()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startTrustPolling() {
        trustTimer?.invalidate()
        guard !isTrusted else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkTrust() }
        }
    }

    private func checkTrust() {
        isTrusted = AXIsProcessTrusted()
        if isTrusted {
            trustTimer?.invalidate()
            trustTimer = nil
        }
    }

    func lock() {
        guard !isLocked else { return }
        errorMessage = nil
        guard blocker.start() else {
            isTrusted = AXIsProcessTrusted()
            errorMessage = "Could not start input blocking. Make sure imClean is enabled in "
                + "System Settings → Privacy & Security → Accessibility, then relaunch it."
            startTrustPolling()
            return
        }

        isLocked = true
        lockedAt = Date()
        escDownAt = nil
        holdProgress = 0
        remainingSeconds = Int(Self.autoUnlockAfter)

        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer

        onLockChange?(true)
    }

    func unlock() {
        guard isLocked else { return }
        blocker.stop()
        tickTimer?.invalidate()
        tickTimer = nil
        lockedAt = nil
        escDownAt = nil
        holdProgress = 0
        isLocked = false
        onLockChange?(false)
    }

    private func tick() {
        let now = Date()

        if let lockedAt {
            let remaining = Self.autoUnlockAfter - now.timeIntervalSince(lockedAt)
            remainingSeconds = max(0, Int(remaining.rounded(.up)))
            if remaining <= 0 { return unlock() }
        }

        if let escDownAt {
            holdProgress = min(1, now.timeIntervalSince(escDownAt) / Self.holdDuration)
            if holdProgress >= 1 { return unlock() }
        } else if holdProgress != 0 {
            holdProgress = 0
        }
    }
}
