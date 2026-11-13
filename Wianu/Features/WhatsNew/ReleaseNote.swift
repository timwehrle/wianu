import Foundation
import OSLog

struct ReleaseNote: Decodable, Identifiable {
    struct Change: Decodable {
        let title: String
        let description: String
        let symbol: String
    }

    let version: String
    let changes: [Change]

    var id: String {
        version
    }

    static func load(bundle: Bundle = .main) -> [ReleaseNote] {
        guard let url = bundle.url(forResource: "ReleaseNotes", withExtension: "json") else { return [] }

        do {
            return try JSONDecoder().decode([ReleaseNote].self, from: Data(contentsOf: url))
        } catch {
            Logger(subsystem: "Wianu", category: "ReleaseNotes")
                .error("Could not load release notes: \(error.localizedDescription)")
            return []
        }
    }
}
