import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @Bindable var model: AppModel
    let onAction: (CommandPaletteAction) -> Void
    let onDismiss: () -> Void

    @FocusState private var searchFieldIsFocused: Bool

    @State private var selectedResult: ResultID?
    @State private var scrollTarget: ResultID?

    private enum ResultID: Hashable {
        case command(CommandPaletteAction)
        case media(TMDBMediaResult.ID)
    }

    private var search: TMDBSearchModel {
        model.tmdbSearch
    }

    private var commands: [CommandPaletteCommand] {
        CommandCatalog.commands(
            matching: search.query,
            sites: model.siteStore.sites,
            continueWatchingItems: model.continueWatchingStore.sortedItems
        )
    }

    private var visibleResultIDs: [ResultID] {
        commands.map { .command($0.action) }
            + (canSelectMediaResults
                ? search.results.map { .media($0.id) }
                : [])
    }

    private var canSelectMediaResults: Bool {
        !trimmedQuery.isEmpty
            && !search.isSearching
            && search.errorMessage == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if let selected = search.selectedMedia {
                TMDBAvailabilityView(model: model, media: selected) {
                    search.clearSelection()
                    searchFieldIsFocused = true
                }
            } else {
                resultsView
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        .onAppear {
            searchFieldIsFocused = true
            selectedResult = visibleResultIDs.first
        }
        .onChange(of: search.focusRequest) {
            searchFieldIsFocused = true
        }
        .onChange(of: visibleResultIDs) { _, ids in
            guard let selectedResult, ids.contains(selectedResult) else {
                selectedResult = ids.first
                return
            }
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
            return selectedResult == nil ? .ignored : .handled
        }
        .onKeyPress(.escape) {
            if search.selectedMedia != nil {
                search.clearSelection()
                searchFieldIsFocused = true
            } else {
                onDismiss()
            }
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(
                "Search Wianu",
                text: Bindable(search).query
            )
            .textFieldStyle(.plain)
            .font(.system(size: 25, weight: .regular))
            .focused($searchFieldIsFocused)
            .onChange(of: search.query) { search.queryChanged() }
            if !search.query.isEmpty {
                Button {
                    search.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear Search")
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 19)
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !commands.isEmpty {
                    sectionHeader("Actions")

                    ForEach(commands) { command in
                        commandRow(command).id(
                            ResultID.command(command.action)
                        )
                    }
                }
                searchResultsSection
            }
            .scrollTargetLayout()
            .padding(8)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .onChange(of: selectedResult) { _, selection in
            scrollTarget = selection
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if !trimmedQuery.isEmpty {
            sectionHeader("Movies & TV")
            mediaResults
        } else if commands.isEmpty {
            compactMessage(
                "No actions available",
                systemImage: "command",
                description: "Add a site to get started."
            )
        }
    }

    @ViewBuilder
    private var mediaResults: some View {
        if search.isSearching {
            HStack {
                Spacer()
                ProgressView("Searching TMDB…").padding(24)
                Spacer()
            }
        } else if let error = search.errorMessage {
            TMDBErrorView(search: search, error: error)
                .frame(minHeight: 180)
        } else if search.results.isEmpty {
            compactMessage(
                "No TMDB results",
                systemImage: "magnifyingglass",
                description: "Try another title or check the spelling."
            )
        } else {
            mediaResultRows
        }
    }

    @ViewBuilder
    private var mediaResultRows: some View {
        ForEach(search.results) { item in
            Button {
                search.select(item)
            } label: {
                paletteMediaRow(
                    item: item,
                    posterURL: search.imageConfiguration?
                        .posterURL(path: item.posterPath)
                )
                .foregroundStyle(rowForeground(selectedResult == .media(item.id)))
                .background(
                    rowBackground(selectedResult == .media(item.id)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .id(ResultID.media(item.id))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    selectedResult = .media(item.id)
                }
            }
            .onAppear {
                search.loadMoreIfNeeded(after: item)
            }
        }
        if search.isLoadingMore {
            ProgressView().padding()
        }
    }

    private var trimmedQuery: String {
        search.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    private func commandRow(_ command: CommandPaletteCommand) -> some View {
        let isSelected = selectedResult == .command(command.action)
        return Button {
            onAction(command.action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.systemImage)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .foregroundStyle(rowForeground(isSelected))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                rowBackground(isSelected),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.8) : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                selectedResult = .command(command.action)
            }
        }
    }

    private func compactMessage(
        _ title: String,
        systemImage: String,
        description: String
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func moveSelection(by offset: Int) {
        let ids = visibleResultIDs
        guard !ids.isEmpty else {
            selectedResult = nil
            return
        }
        guard let selectedResult,
              let index = ids.firstIndex(of: selectedResult)
        else {
            selectedResult = ids.first
            return
        }
        self.selectedResult = ids[(index + offset + ids.count) % ids.count]
    }

    private func activateSelection() {
        switch selectedResult {
        case let .command(action):
            onAction(action)
        case let .media(id):
            guard let media = search.results.first(where: { $0.id == id })
            else {
                return
            }
            search.select(media)
        case nil:
            break
        }
    }
}

private extension CommandPaletteView {
    private func rowBackground(_ isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.35) : .clear
    }

    private func rowForeground(_ isSelected: Bool) -> Color {
        Color(nsColor: .labelColor)
    }

    private func paletteMediaRow(item: TMDBMediaResult, posterURL: URL?) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "film")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
            .frame(width: 30, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text([item.mediaType == .movie ? "Movie" : "TV Show", item.year]
                    .compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 12))
                    .opacity(0.7)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
