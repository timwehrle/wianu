import SwiftUI

struct MediaIdentificationResultRow: View {
    let media: TMDBMediaResult
    let posterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: media.mediaType == .movie ? "film" : "tv")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 72)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(media.title).font(.headline)
                Text([media.year, media.mediaType == .movie ? "Movie" : "TV Show"].compactMap(\.self)
                    .joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                if !media.overview.isEmpty {
                    Text(media.overview).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
