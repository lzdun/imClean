import SwiftUI

struct MainView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("imClean")
                .font(.largeTitle.bold())

            Text("Locks the keyboard and trackpad so you can wipe them clean.\nHold Esc for \(Int(AppState.holdDuration)) seconds to unlock.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if state.isTrusted {
                Button("Start Cleaning") { state.lock() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            } else {
                VStack(spacing: 8) {
                    Text("imClean needs Accessibility permission to block input.")
                        .font(.callout)
                    HStack {
                        Button("Request Permission") { state.requestAccessibility() }
                        Button("Open System Settings") { state.openAccessibilitySettings() }
                    }
                }
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("Unlocks automatically after \(Int(AppState.autoUnlockAfter / 60)) minutes. The power button and Touch ID cannot be blocked.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 440)
    }
}

struct OverlayView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))

                Text("Keyboard & Trackpad Locked")
                    .font(.system(size: 36, weight: .bold))

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: state.holdProgress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("esc")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                }
                .frame(width: 120, height: 120)

                Text("Hold Esc for \(Int(AppState.holdDuration)) seconds to unlock")
                    .font(.title2)

                Text("Auto-unlock in \(state.remainingSeconds / 60):\(String(format: "%02d", state.remainingSeconds % 60))")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
        }
    }
}
