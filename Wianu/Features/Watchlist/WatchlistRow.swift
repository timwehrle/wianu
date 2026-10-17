import SwiftUI

struct WatchlistRow: View {
    let item: WatchlistItem
    var needsReview = false

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)

                if needsReview {
                    Text("Needs identification").font(.caption).foregroundStyle(.secondary)
                }
                if let year = item.year {
                    Text(year.formatted(.number.grouping(.never)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: item.tmdbMediaType == .tv ? "tv" : "film")
                .foregroundStyle(.secondary)
        }
        .help(item.title)
    }
}
