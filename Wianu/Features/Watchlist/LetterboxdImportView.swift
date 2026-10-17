import SwiftUI

struct LetterboxdImportView: View {
    let url: URL
    let existingItems: [WatchlistItem]
    let client: TMDBClient
    let commit: ([WatchlistItem]) -> Void
    let report: (String) -> Void

    @State private var model = LetterboxdImportModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                progress
                    .interactiveDismissDisabled()
            } else {
                LetterboxdImportReviewView(entries: model.entries, skipped: model.skippedCount, commit: commit)
            }
        }
        .task {
            await model.load(from: url, existingItems: existingItems, client: client)

            if model.entries.isEmpty {
                dismiss()

                if let message = model.message {
                    report(message)
                }
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Import Letterboxd Watchlist").font(.headline)
                Text(model.totalCount == 0
                    ? "Reading watchlist…"
                    : "Matching \(min(model.completedCount + 1, model.totalCount)) of \(model.totalCount) films")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(model.completedCount), total: Double(max(model.totalCount, 1)))
                Text(model.currentTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
