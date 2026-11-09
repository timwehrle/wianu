import Foundation
import Observation

@MainActor
@Observable
final class SiteStore {
    private(set) var sites: [SavedSite] = []
    private(set) var persistenceError: String?

    @ObservationIgnored
    private let fileStore: JSONFileStore<[SavedSite]>

    init(
        fileStore: JSONFileStore<[SavedSite]> = JSONFileStore(
            fileName: "sites.json",
            folderName: "Wianu"
        )
    ) {
        self.fileStore = fileStore
        load()
    }

    @discardableResult
    func addSite(_ draft: SiteDraft) -> Bool {
        guard let values = draft.validatedValues else { return false }

        var updatedSites = sites
        updatedSites.append(
            SavedSite(
                name: values.name,
                urlString: values.url.absoluteString,
                searchURLTemplate: values.searchURLTemplate,
                tmdbProviders: values.tmdbProviders
            )
        )
        return persist(updatedSites)
    }

    @discardableResult
    func updateSite(id: SavedSite.ID, with draft: SiteDraft) -> Bool {
        guard let index = sites.firstIndex(where: { $0.id == id }),
              let values = draft.validatedValues
        else { return false }

        var updatedSites = sites
        updatedSites[index].name = values.name
        updatedSites[index].urlString = values.url.absoluteString
        updatedSites[index].searchURLTemplate = values.searchURLTemplate
        updatedSites[index].tmdbProviders = values.tmdbProviders

        return persist(updatedSites)
    }

    func deleteSite(id: SavedSite.ID) {
        sites.removeAll { $0.id == id }
        persist(sites)
    }

    private func load() {
        do {
            sites = try fileStore.load(defaultValue: [])
            persistenceError = nil
        } catch {
            sites = []
            persistenceError = error.localizedDescription
        }
    }

    @discardableResult
    private func persist(_ updatedSites: [SavedSite]) -> Bool {
        do {
            try fileStore.save(updatedSites)
            sites = updatedSites
            persistenceError = nil
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
        }
    }
}
