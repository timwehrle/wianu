import SwiftUI

struct MediaIdentificationMenu: View {
    let target: MediaIdentificationTarget
    let coordinator: MediaIdentificationCoordinator
    let identify: () -> Void

    var body: some View {
        if let metadata = coordinator.metadata(for: target) {
            Text("\(metadata.title) · \(metadata.mediaType == .movie ? "Movie" : "TV Show")")
        }
        Button(coordinator.isIdentified(target) ? "Change Match…" : "Identify…", action: identify)
    }
}
