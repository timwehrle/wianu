import SwiftUI

struct HomeView: View {
    let model: AppModel
    private enum WeeklyState {
        case loading
        case loaded([TMDBMediaResult])
        case failed(String)
    }

    @State private var weeklyState: WeeklyState = .loading
    @State private var loadRequest = 0
    @State private var featuredID: Int?

    private var weekly: [TMDBMediaResult] {
        guard case let .loaded(movies) = weeklyState else { return [] }
        return movies
    }

    private var featured: TMDBMediaResult? {
        weekly.first { $0.id == featuredID } ?? weekly.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let featured {
                    HomeFeature(
                        media: featured,
                        artworkURL: model.tmdbSearch.imageConfiguration?.backdropURL(path: featured.backdropPath),
                        position: (weekly.firstIndex(of: featured) ?? 0) + 1,
                        count: weekly.count,
                        previous: { changeFeature(by: -1) },
                        next: { changeFeature(by: 1) },
                        action: { model.openWeeklyPick(featured) }
                    )
                }
                continueWatchingShelf
                weeklyShelf
                watchlistShelf
            }
            .padding(.bottom, 32)
            .padding(.top, featured == nil ? 24 : 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem {
                Button { model.showCommandPalette() } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .help("Find a movie or TV show")
            }
        }
        .task(id: loadRequest) { await loadWeekly() }
    }

    @ViewBuilder
    private var weeklyShelf: some View {
        switch weeklyState {
        case .loading:
            ProgressView("Loading this week’s picks…").padding(.horizontal, 32)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 10) {
                Text(message).foregroundStyle(.secondary)
                Button("Retry") { loadRequest += 1 }
            }
            .padding(.horizontal, 32)
        case let .loaded(movies):
            if movies.isEmpty {
                information("No picks available this week.")
            } else {
                HomeShelf(title: "Wianu Weekly") {
                    ForEach(movies) { media in
                        card(media, actionLabel: "Find Providers") { model.openWeeklyPick(media) }
                    }
                }
            }
        }
    }

    private var continueWatchingShelf: some View {
        let items = model.continueWatchingStore.sortedItems.compactMap { item in
            item.tmdbMetadata.map { (id: item.id, media: $0) }
        }
        return Group {
            if items.isEmpty {
                information("Identify a saved title from the sidebar to see it in Continue Watching.")
            } else {
                HomeShelf(title: "Continue Watching") {
                    ForEach(items, id: \.id) { item in
                        card(item.media, actionLabel: "Open Saved Page", showsPlayIcon: true) {
                            model.select(.continueWatching(item.id))
                        }
                    }
                }
            }
        }
    }

    private var watchlistShelf: some View {
        let items = model.watchlistStore.items.compactMap { item in
            item.tmdbMetadata.map { (id: item.id, media: $0) }
        }
        return Group {
            if items.isEmpty {
                information("Add or import titles, then identify them from the sidebar to see them in Watchlist.")
            } else {
                HomeShelf(title: "Watchlist") {
                    ForEach(items, id: \.id) { item in
                        card(item.media, actionLabel: "Find Providers") { showProviders(for: item.media) }
                    }
                }
            }
        }
    }

    private func card(
        _ media: TMDBMediaResult,
        actionLabel: String,
        showsPlayIcon: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HomePosterCard(
            media: media,
            posterURL: model.tmdbSearch.imageConfiguration?.posterURL(path: media.posterPath),
            actionLabel: actionLabel,
            showsPlayIcon: showsPlayIcon,
            action: action
        )
    }

    private func information(_ message: String) -> some View {
        Text(message).foregroundStyle(.secondary).padding(.horizontal, 32)
    }

    private func changeFeature(by offset: Int) {
        guard !weekly.isEmpty else { return }
        let index = weekly.firstIndex { $0.id == featured?.id } ?? 0
        featuredID = weekly[(index + offset + weekly.count) % weekly.count].id
    }

    private func showProviders(for media: TMDBMediaResult) {
        model.showCommandPalette(query: media.title)
        model.tmdbSearch.select(media)
    }

    private func loadWeekly() async {
        weeklyState = .loading
        do {
            let movies = try await model.tmdbClient.weeklyMovies()
            try Task.checkCancellation()
            weeklyState = .loaded(movies)
        } catch {
            guard !Task.isCancelled else { return }
            weeklyState = .failed("Couldn’t load Wianu Weekly. \(error.localizedDescription)")
        }
    }
}

private enum HomeShelfLayout {
    static let posterWidth: CGFloat = 180
    static let spacing: CGFloat = 20
}

private struct HomeShelf<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(x: 0)
    @State private var metrics = HomeShelfScrollMetrics(offset: 0, viewportWidth: 0, contentWidth: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                ControlGroup {
                    Button("Previous Titles", systemImage: "chevron.left") { page(by: -1) }
                        .disabled(metrics.offset <= 1)
                    Button("Next Titles", systemImage: "chevron.right") { page(by: 1) }
                        .disabled(metrics.offset >= metrics.maximumOffset - 1)
                }
                .labelStyle(.iconOnly)
                .controlSize(.small)
                .accessibilityLabel("\(title) navigation")
            }
            .padding(.horizontal, 32)
            ScrollView(.horizontal) {
                LazyHStack(spacing: HomeShelfLayout.spacing) { content }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 4)
            }
            .frame(height: 290)
            .scrollIndicators(.visible, axes: .horizontal)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollPosition($position)
            .onScrollGeometryChange(for: HomeShelfScrollMetrics.self) { geometry in
                HomeShelfScrollMetrics(
                    offset: max(0, geometry.contentOffset.x),
                    viewportWidth: geometry.containerSize.width,
                    contentWidth: geometry.contentSize.width
                )
            } action: { _, updated in
                metrics = updated
            }
        }
    }

    private func page(by direction: CGFloat) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            position.scrollTo(x: metrics.destination(direction: direction))
        }
    }
}

struct HomeShelfScrollMetrics: Equatable {
    let offset: CGFloat
    let viewportWidth: CGFloat
    let contentWidth: CGFloat

    var maximumOffset: CGFloat {
        max(0, contentWidth - viewportWidth)
    }

    func destination(direction: CGFloat) -> CGFloat {
        // Keep one card overlapping between pages to preserve the reader's place.
        let cardStride = HomeShelfLayout.posterWidth + HomeShelfLayout.spacing
        let pageWidth = max(cardStride, viewportWidth - cardStride)
        return min(maximumOffset, max(0, offset + direction * pageWidth))
    }
}

private struct HomeFeature: View {
    let media: TMDBMediaResult
    let artworkURL: URL?
    let position: Int
    let count: Int
    let previous: () -> Void
    let next: () -> Void
    let action: () -> Void

    var body: some View {
        Color.black
            .frame(height: 360)
            .overlay {
                HomeArtwork(url: artworkURL, contentMode: .fill, placeholderTitle: nil)
            }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Week’s Pick").font(.subheadline.weight(.medium))
                    Text(media.title).font(.largeTitle.bold()).lineLimit(2)
                    Text([media.year, media.mediaType == .movie ? "Movie" : "TV Show"]
                        .compactMap(\.self).joined(separator: " · "))
                        .foregroundStyle(.secondary)
                    Button("Where to Watch", systemImage: "play.fill", action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .frame(maxWidth: 600, alignment: .leading)
                .padding(32)
            }
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    ControlGroup {
                        Button("Previous Pick", systemImage: "chevron.left", action: previous)
                        Button("Next Pick", systemImage: "chevron.right", action: next)
                    }
                    .labelStyle(.iconOnly)
                    .help("Weekly pick \(position) of \(count)")
                    .padding(24)
                }
            }
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white)
            .clipped()
    }
}

private struct HomePosterCard: View {
    let media: TMDBMediaResult
    let posterURL: URL?
    let actionLabel: String
    let showsPlayIcon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HomeArtwork(url: posterURL, contentMode: .fill, placeholderTitle: media.title)
                .frame(width: HomeShelfLayout.posterWidth, height: 270)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            if showsPlayIcon {
                                Image(systemName: "play.fill")
                            }
                            Text([media.year, media.mediaType == .movie ? "Movie" : "TV Show"]
                                .compactMap(\.self).joined(separator: " · "))
                        }
                        .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    .background {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12))
                }
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(actionLabel): \(media.title)")
        .help("\(media.title) — \(actionLabel)")
        .contextMenu {
            Button(actionLabel, action: action)
        }
    }
}

private struct HomeArtwork: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholderTitle: String?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                GeometryReader { geometry in
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: contentMode)
                    } placeholder: {
                        VStack(spacing: 12) {
                            Image(systemName: "film").font(.largeTitle).foregroundStyle(.tertiary)
                            if let placeholderTitle {
                                Text(placeholderTitle).font(.headline).multilineTextAlignment(.center).lineLimit(3)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
            }
            .accessibilityHidden(true)
    }
}
