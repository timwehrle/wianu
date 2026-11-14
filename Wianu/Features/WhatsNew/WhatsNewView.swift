import SwiftUI

struct WhatsNewView: View {
    let notes: [ReleaseNote]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("What’s New in Wianu")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Version \(note.version)")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(note.changes.indices, id: \.self) { index in
                                let change = note.changes[index]
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: change.symbol)
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 32)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(change.title).font(.headline)
                                        Text(change.description)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Continue") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 500, height: 520)
    }
}
