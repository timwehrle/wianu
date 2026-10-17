import SwiftUI

struct MediaIdentificationView: View {
    let currentMatch: TMDBMediaResult?
    let hasMatch: Bool
    let client: TMDBClient
    let onSelect: (TMDBMediaResult?) -> Void
    private let moviesOnly: Bool

    @State private var title: String
    @State private var year: String
    @State private var mediaType: TMDBMediaType?
    @State private var selected: MediaIdentity?
    @State private var retry = 0
    @State private var model = MediaIdentificationModel()
    @Environment(\.dismiss) private var dismiss

    private struct SearchRequest: Hashable {
        let query: MediaIdentificationQuery
        let retry: Int
    }

    init(
        query: MediaIdentificationQuery,
        currentMatch: TMDBMediaResult?,
        hasMatch: Bool,
        client: TMDBClient,
        onSelect: @escaping (TMDBMediaResult?) -> Void
    ) {
        self.currentMatch = currentMatch
        self.hasMatch = hasMatch
        self.client = client
        self.onSelect = onSelect
        moviesOnly = query.mediaType == .movie
        _title = State(initialValue: query.title)
        _year = State(initialValue: query.year.map(String.init) ?? "")
        _mediaType = State(initialValue: query.mediaType)
        _selected = State(initialValue: currentMatch?.identity)
    }

    private var query: MediaIdentificationQuery {
        MediaIdentificationQuery(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            year: Int(year),
            mediaType: mediaType
        )
    }

    private var validQuery: Bool {
        guard !query.title.isEmpty else { return false }
        if year.isEmpty {
            return true
        }
        guard year.count == 4, let year = Int(year) else { return false }
        return (1800 ... 2200).contains(year)
    }

    private var selectedMedia: TMDBMediaResult? {
        guard validQuery, !model.isSearching, model.query == query else { return nil }
        return model.result?.candidates.first { $0.identity == selected }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hasMatch ? "Change Match" : "Identify Film or TV Show").font(.headline)
                Text("Choose the correct title. Your saved name, link, and provider will stay unchanged.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Title", text: $title)
                    .accessibilityLabel("Search title")
                TextField("Year", text: $year)
                    .frame(width: 65)
                    .accessibilityLabel("Release year, optional")
                Picker("Type", selection: $mediaType) {
                    if !moviesOnly {
                        Text("Movies & TV").tag(TMDBMediaType?.none)
                    }
                    Text("Movies").tag(Optional(TMDBMediaType.movie))
                    if !moviesOnly {
                        Text("TV Shows").tag(Optional(TMDBMediaType.tv))
                    }
                }.labelsHidden()
            }
            if let currentMatch {
                Text(
                    "Current match: \(currentMatch.title) (\(currentMatch.year ?? "Unknown year")) · \(currentMatch.mediaType == .movie ? "Movie" : "TV")"
                )
                .font(.callout).foregroundStyle(.secondary)
            }
            if let reason = model.result?.reviewReason {
                Text(reason).font(.callout).foregroundStyle(.secondary)
            }
            results
            HStack {
                if hasMatch {
                    Button("Remove Match") { onSelect(nil)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Use Selected Match") {
                    guard let selectedMedia else { return }
                    onSelect(selectedMedia)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedMedia == nil)
            }
        }
        .padding(24)
        .frame(width: 680, height: 540)
        .task(id: SearchRequest(query: query, retry: retry)) {
            guard validQuery else { return }
            await model.search(query, client: client)
        }
        .task { await model.loadImages(client: client) }
        .onChange(of: model.result?.candidates) {
            let candidates = model.result?.candidates ?? []
            selected = candidates.contains { $0.identity == currentMatch?.identity }
                ? currentMatch?.identity : model.result?.match?.identity
        }
    }

    @ViewBuilder
    private var results: some View {
        if !validQuery {
            ContentUnavailableView(
                "Enter a Title",
                systemImage: "magnifyingglass",
                description: Text("Use a title and an optional four-digit year.")
            )
        } else if model.isSearching {
            ProgressView("Searching…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage {
            ContentUnavailableView {
                Label("Couldn’t Identify Title", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { retry += 1 }
            }
        } else if let result = model.result, !result.candidates.isEmpty {
            List(selection: $selected) {
                ForEach(result.candidates, id: \.identity) { media in
                    MediaIdentificationResultRow(
                        media: media,
                        posterURL: model.images?.posterURL(path: media.posterPath)
                    )
                    .tag(media.identity)
                }
            }
        } else {
            ContentUnavailableView(
                "No Matches",
                systemImage: "magnifyingglass",
                description: Text("Try a different title or year. You can keep the entry without a match.")
            )
        }
    }
}
