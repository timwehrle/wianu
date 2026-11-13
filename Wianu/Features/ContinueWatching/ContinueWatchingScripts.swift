import Foundation

enum ContinueWatchingScripts {
    private static let observer = BundledJavaScript.load("ContinueWatchingObserver")
    private static let services: [ContinueWatchingService: String] = [
        .hboMax: BundledJavaScript.load("HBOMax"),
        .netflix: BundledJavaScript.load("Netflix"),
        .primeVideo: BundledJavaScript.load("PrimeVideo"),
        .disneyPlus: BundledJavaScript.load("DisneyPlus"),
        .appleTV: BundledJavaScript.load("AppleTV")
    ]

    static func source(for adapter: ContinueWatchingAdapter) -> String {
        guard let script = services[adapter.id] else {
            preconditionFailure("Missing JavaScript for \(adapter.name)")
        }

        if adapter.id == .hboMax {
            return script
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: [
                "id": adapter.id.rawValue,
                "name": adapter.name,
                "hosts": adapter.hosts
            ])
            guard let configuration = String(data: data, encoding: .utf8) else {
                preconditionFailure("Invalid UTF-8 JavaScript configuration for \(adapter.name)")
            }

            return """
            (() => {
                \(observer)
                \(script)
                observeContinueWatching(\(configuration), createContinueWatchingReader);
            })();
            """
        } catch {
            preconditionFailure("Could not encode JavaScript configuration for \(adapter.name): \(error)")
        }
    }
}
