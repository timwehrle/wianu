import Foundation

enum BundledJavaScript {
    static func load(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else {
            preconditionFailure("Missing bundled JavaScript: \(name).js")
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            preconditionFailure("Could not read bundled JavaScript \(name).js: \(error)")
        }
    }
}
