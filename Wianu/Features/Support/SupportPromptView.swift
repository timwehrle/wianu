import SwiftUI

struct SupportPromptView: View {
    let onDismiss: (_ permanently: Bool) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(.pink)

            Text("Enjoying Wianu?")
                .font(.title2.bold())

            Text("I'm Tim, the developer behind Wianu. If it's made your movie nights a little easier, "
                + "consider supporting my work. Your support helps me keep building and improving the app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Support Wianu") {
                openURL(SupportPromptModel.supportURL) { accepted in
                    // Ko-fi cannot confirm donations so honor the choice to support by stopping reminders.
                    onDismiss(accepted)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Maybe later") { onDismiss(false) }
                .keyboardShortcut(.cancelAction)

            Button("Don't ask again") { onDismiss(true) }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 380)
    }
}
