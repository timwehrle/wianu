import Foundation
import Observation

@MainActor
@Observable
final class MediaIdentificationModel {
    @ObservationIgnored private var generation = UUID()
    private(set) var query: MediaIdentificationQuery?
    private(set) var isSearching = false
    private(set) var result: MediaIdentificationResult?
    private(set) var errorMessage: String?
    private(set) var images: TMDBImageConfiguration?

    func search(_ query: MediaIdentificationQuery, client: TMDBClient) async {
        let token = UUID()
        generation = token
        self.query = nil
        isSearching = true
        result = nil
        errorMessage = nil
        defer {
            if generation == token {
                isSearching = false
            }
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let response = try await MediaIdentificationService(client: client).search(query)
            try Task.checkCancellation()
            guard generation == token else { return }
            self.query = query
            result = response
        } catch {
            if !Task.isCancelled, generation == token {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadImages(client: TMDBClient) async {
        images = try? await client.imageConfiguration()
    }
}
