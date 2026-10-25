import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var model: AppModel
    @Binding var showingAddSite: Bool

    @State private var editingSite: SavedSite?
    @State private var renamingItem: ContinueWatchingItem?
    @State private var pendingDeletion: SidebarDeletion?
    @State private var showingWatchlistImporter = false
    @State private var showingAddWatchlistItem = false
    @State private var editingWatchlistItem: WatchlistItem?
    @State private var identificationTarget: MediaIdentificationTarget?
    @State private var importURL: URL?
    @State private var importMessage: String?
    @State private var sitesExpanded = true
    @State private var continueWatchingExpanded = true
    @State private var watchlistExpanded = true

    var body: some View {
        List(selection: selectionBinding) {
            searchButton
            Label("Home", systemImage: "house")
                .tag(SidebarSelection.home)
            sitesSection
            continueWatchingSection
            watchlistSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .sheet(item: $editingSite) { site in
            SiteEditorView(
                model: model,
                mode: .edit(site)
            )
        }
        .sheet(item: $renamingItem) { item in
            RenameContinueWatchingView(item: item) { title in
                model.continueWatchingStore.rename(id: item.id, to: title)
                model.mediaIdentification.identifyInBackground(.continueWatching(item.id))
            }
        }
        .sheet(isPresented: $showingAddWatchlistItem) {
            WatchlistItemEditorView { title, year, url in
                model.addWatchlistItem(
                    title: title,
                    year: year,
                    url: url
                )
            }
        }
        .sheet(item: $editingWatchlistItem) { item in
            WatchlistItemEditorView(item: item) { title, year, url in
                model.updateWatchlistItem(
                    item,
                    title: title,
                    year: year,
                    url: url
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { importURL != nil },
            set: {
                if !$0 {
                    importURL = nil
                }
            }
        )) {
            if let importURL {
                LetterboxdImportView(
                    url: importURL,
                    existingItems: model.watchlistStore.items,
                    client: model.tmdbClient,
                    commit: completeImport,
                    report: { importMessage = $0 }
                )
            }
        }
        .sheet(item: $identificationTarget) { target in
            if let query = model.mediaIdentification.query(for: target) {
                MediaIdentificationView(
                    query: query,
                    currentMatch: model.mediaIdentification.metadata(for: target),
                    hasMatch: model.mediaIdentification.isIdentified(target),
                    client: model.tmdbClient
                ) { media in
                    model.mediaIdentification.associate(media, with: target)
                }
                .onAppear { model.mediaIdentification.cancel(target, clearResult: false) }
            }
        }
        .fileImporter(
            isPresented: $showingWatchlistImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: importWatchlist
        )
        .alert(
            pendingDeletion?.title ?? "",
            isPresented: isPresenting($pendingDeletion),
            presenting: pendingDeletion
        ) { deletion in
            Button(deletion.actionTitle, role: .destructive) {
                delete(deletion)
            }

            Button("Cancel", role: .cancel) {}
        } message: { deletion in
            Text(deletion.message)
        }
        .alert(
            "Letterboxd Import",
            isPresented: isPresenting($importMessage),
            presenting: importMessage
        ) { _ in
            Button("OK") {
                importMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }

    private var searchButton: some View {
        Button {
            model.showCommandPalette()
        } label: {
            Label("Search", systemImage: "magnifyingglass")
        }
        .buttonStyle(.plain)
    }

    private var sitesSection: some View {
        Section("Sites", isExpanded: $sitesExpanded) {
            ForEach(model.siteStore.sites) { site in
                SiteRow(site: site)
                    .tag(SidebarSelection.site(site.id))
                    .contextMenu {
                        Button("Edit") { editingSite = site }
                        Divider()
                        Button("Delete", role: .destructive) {
                            pendingDeletion = .site(site)
                        }
                    }
            }

            Button {
                showingAddSite = true
            } label: {
                Label("Add Site", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var continueWatchingSection: some View {
        if !model.continueWatchingStore.sortedItems.isEmpty {
            Section(
                "Continue Watching",
                isExpanded: $continueWatchingExpanded
            ) {
                ForEach(model.continueWatchingStore.sortedItems) { item in
                    ContinueWatchingRow(
                        item: item,
                        site: site(for: item),
                        needsReview: model.mediaIdentification.needsReview(.continueWatching(item.id))
                    )
                    .tag(SidebarSelection.continueWatching(item.id))
                    .contextMenu {
                        MediaIdentificationMenu(
                            target: .continueWatching(item.id),
                            coordinator: model.mediaIdentification
                        ) {
                            identificationTarget = .continueWatching(item.id)
                        }
                        Divider()
                        Button("Rename") { renamingItem = item }
                        Divider()
                        Button("Remove", role: .destructive) {
                            pendingDeletion = .continueWatching(item)
                        }
                    }
                }
            }
        }
    }

    private var watchlistSection: some View {
        Section("Watchlist", isExpanded: $watchlistExpanded) {
            ForEach(model.watchlistStore.items) { item in
                WatchlistRow(item: item, needsReview: model.mediaIdentification.needsReview(.watchlist(item.id)))
                    .tag(SidebarSelection.watchlistItem(item.id))
                    .contextMenu { watchlistContextMenu(for: item) }
            }

            Button {
                showingAddWatchlistItem = true
            } label: {
                Label("Add Movie", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Button {
                showingWatchlistImporter = true
            } label: {
                Label(
                    importURL != nil ? "Matching films…" : "Import Letterboxd CSV…",
                    systemImage: "square.and.arrow.down"
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(importURL != nil)
        }
    }

    @ViewBuilder
    private func watchlistContextMenu(for item: WatchlistItem) -> some View {
        MediaIdentificationMenu(target: .watchlist(item.id), coordinator: model.mediaIdentification) {
            identificationTarget = .watchlist(item.id)
        }
        Divider()
        Button("Find Providers") {
            model.showCommandPalette(query: item.title)
        }

        Divider()

        if item.source == .custom {
            Button("Edit") { editingWatchlistItem = item }
            Divider()
        }

        Button("Remove", role: .destructive) {
            pendingDeletion = .watchlistItem(item)
        }
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { model.selection },
            set: model.select
        )
    }

    private func site(for item: ContinueWatchingItem) -> SavedSite? {
        model.siteStore.sites.first { $0.id == item.siteID }
    }

    private func importWatchlist(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            importURL = url

        case let .failure(error):
            if (error as? CocoaError)?.code != .userCancelled {
                importMessage = error.localizedDescription
            }
        }
    }

    private func completeImport(_ items: [WatchlistItem]) {
        model.watchlistStore.mergeImportedItems(items)
        model.letterboxdImportSucceeded()
        importMessage = model.watchlistStore.persistenceError
            ?? "Imported \(items.count) films. \(items.filter { $0.tmdbID != nil }.count) matched to TMDB."
    }

    private func delete(_ deletion: SidebarDeletion) {
        switch deletion {
        case let .site(site):
            model.deleteSite(site)
        case let .continueWatching(item):
            model.removeContinueWatchingItem(item)
        case let .watchlistItem(item):
            model.removeWatchlistItem(item)
        }
    }

    private func isPresenting(_ item: Binding<(some Any)?>) -> Binding<Bool> {
        Binding(
            get: { item.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    item.wrappedValue = nil
                }
            }
        )
    }
}
