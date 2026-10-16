import Foundation
import Observation

@MainActor
@Observable
final class TMDBSearchModel {
    var query = ""
    private(set) var results: [TMDBMediaResult] = []
    private(set) var selectedMedia: TMDBMediaResult?
    private(set) var availability: TMDBWatchAvailability?
    private(set) var regions: [TMDBRegion] = []
    private(set) var imageConfiguration: TMDBImageConfiguration?
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var isLoadingProviders = false
    private(set) var errorMessage: String?
    private(set) var focusRequest = 0
    private(set) var selectedRegion: String

    @ObservationIgnored private let client: TMDBClient
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var providerTask: Task<Void, Never>?
    @ObservationIgnored private var metadataTask: Task<Void, Never>?
    private var currentPage = 0
    private var totalPages = 0
    private var searchGeneration = 0
    private var providerGeneration = 0

    private static let regionKey = "tmdbRegion"
    private static let hasSelectedRegionKey = "hasSelectedTMDBRegion"

    init(client: TMDBClient, userDefaults: UserDefaults) {
        self.client = client
        self.userDefaults = userDefaults
        let systemRegion = Locale.current.region?.identifier ?? "US"

        if userDefaults.bool(forKey: Self.hasSelectedRegionKey),
           let savedRegion = userDefaults.string(forKey: Self.regionKey)
        {
            selectedRegion = savedRegion
        } else {
            selectedRegion = systemRegion
            userDefaults.removeObject(forKey: Self.regionKey)
        }

        loadMetadataIfNeeded()
    }

    var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }

    func requestFocus() {
        focusRequest += 1
    }

    func selectRegion(_ region: String) {
        guard region != selectedRegion else { return }

        selectedRegion = region
        userDefaults.set(region, forKey: Self.regionKey)
        userDefaults.set(true, forKey: Self.hasSelectedRegionKey)

        if selectedMedia != nil {
            loadAvailability()
        }
    }

    func queryChanged() {
        loadMetadataIfNeeded()
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        selectedMedia = nil
        availability = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false

            return
        }

        results = []
        currentPage = 0
        totalPages = 0
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))

            guard !Task.isCancelled else { return }

            await search(query: trimmed, page: 1, generation: generation)
        }
    }

    func retry() {
        if selectedMedia != nil {
            loadAvailability()
        } else {
            queryChanged()
        }
    }

    func loadMoreIfNeeded(after item: TMDBMediaResult) {
        guard item.id == results.last?.id, canLoadMore else { return }

        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let generation = searchGeneration

        searchTask = Task {
            await search(
                query: query,
                page: currentPage + 1,
                generation: generation
            )
        }
    }

    func select(_ media: TMDBMediaResult) {
        selectedMedia = media
        availability = nil
        loadAvailability()
    }

    func clearSelection() {
        providerTask?.cancel()
        providerGeneration += 1
        selectedMedia = nil
        availability = nil
        isLoadingProviders = false
        errorMessage = nil
    }

    private func search(query: String, page: Int, generation: Int) async {
        guard generation == searchGeneration else { return }

        if page == 1 {
            isSearching = true
        } else {
            isLoadingMore = true
        }

        errorMessage = nil

        do {
            let response = try await client.search(query: query, page: page)
            try Task.checkCancellation()

            guard generation == searchGeneration else { return }

            if page == 1 {
                results = response.results
            } else {
                results.append(contentsOf: response.results)
            }

            currentPage = response.page
            totalPages = response.totalPages
        } catch {
            if !isCancellation(error), generation == searchGeneration {
                errorMessage = error.localizedDescription
            }
        }

        guard generation == searchGeneration else { return }

        if page == 1 {
            isSearching = false
        } else {
            isLoadingMore = false
        }
    }

    private func loadAvailability() {
        providerTask?.cancel()
        providerGeneration += 1

        let generation = providerGeneration

        guard let selectedMedia else { return }

        isLoadingProviders = true
        errorMessage = nil

        providerTask = Task {
            do {
                availability = try await client.watchProviders(
                    for: selectedMedia,
                    region: selectedRegion
                )
            } catch {
                if !isCancellation(error), generation == providerGeneration {
                    errorMessage = error.localizedDescription
                }
            }

            guard generation == providerGeneration else { return }

            isLoadingProviders = false
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError
            || (error as? URLError)?.code == .cancelled
    }

    private func loadMetadata() async {
        async let loadedRegions = client.regions()
        async let loadedImages = client.imageConfiguration()

        regions = await (try? loadedRegions) ?? []
        imageConfiguration = try? await loadedImages

        if !regions.isEmpty,
           !regions.contains(where: { $0.isoCode == selectedRegion })
        {
            selectedRegion = regions.contains(where: { $0.isoCode == "US" })
                ? "US"
                : regions[0].isoCode
            userDefaults.removeObject(forKey: Self.regionKey)
            userDefaults.removeObject(forKey: Self.hasSelectedRegionKey)
        }
    }

    private func loadMetadataIfNeeded() {
        guard imageConfiguration == nil, metadataTask == nil else { return }

        metadataTask = Task {
            await loadMetadata()
            metadataTask = nil
        }
    }
}
