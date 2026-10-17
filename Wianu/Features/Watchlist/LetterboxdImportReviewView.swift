import SwiftUI

struct LetterboxdImportReviewView: View {
    @State var entries: [ImportReviewEntry]
    let skipped: Int
    let commit: ([WatchlistItem]) -> Void
    @Environment(\.dismiss) private var dismiss

    private var matched: Int {
        entries.filter { $0.selectedID != nil }.count
    }

    private var unmatched: Int {
        entries.filter { $0.classification == .unmatched && $0.error == nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Review Letterboxd Import").font(.headline)
                Text(
                    "\(matched) matched · \(entries.count - matched - unmatched) needs review · \(unmatched) unmatched"
                )
                .foregroundStyle(.secondary)
                Text("Films without a selection keep their original information.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if skipped > 0 {
                    Text("\(skipped) duplicate or invalid entries skipped.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            List($entries) { $entry in
                VStack(alignment: .leading) {
                    Text(entry.item.title + (entry.item.year.map { " (\($0))" } ?? ""))

                    if let reason = entry.reviewReason {
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }

                    if let error = entry.error {
                        Text("Search failed: \(error)").font(.caption).foregroundStyle(.secondary)
                    }

                    Picker("TMDB film", selection: $entry.selectedID) {
                        Text("Keep without TMDB match").tag(Int?.none)
                        ForEach(entry.candidates) { candidate in
                            Text("\(candidate.title) (\(candidate.year ?? "unknown year")) · TMDB \(candidate.id)")
                                .tag(Optional(candidate.id))
                        }
                    }
                }.padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import \(entries.count) Films") {
                    commit(entries.map(\.resolvedItem))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 520)
    }
}
