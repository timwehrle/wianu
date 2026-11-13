import SwiftUI

struct ContinueWatchingSidebarSection: View {
    @Bindable var model: AppModel
    @State private var isExpanded = true

    var body: some View {
        let queues = model.sidebarContinueWatchingQueues

        if !queues.isEmpty {
            Section("Continue Watching", isExpanded: $isExpanded) {
                ForEach(queues) { queue in
                    ContinueWatchingGroup(model: model, queue: queue)
                }
            }
        }
    }
}

private struct ContinueWatchingGroup: View {
    @Bindable var model: AppModel
    @Bindable var queue: ContinueWatchingController
    @State private var isExpanded: Bool
    @State private var isHovered = false
    @FocusState private var isRefreshFocused: Bool

    init(model: AppModel, queue: ContinueWatchingController) {
        self.model = model
        self.queue = queue
        _isExpanded = State(initialValue: !queue.entries.isEmpty)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            queueContent
        } label: {
            HStack {
                Label {
                    Text(queue.adapter.name)
                        .lineLimit(1)
                } icon: {
                    FaviconView(url: model.continueWatchingSite(for: queue.id)?.url)
                }

                Spacer()

                refreshButton
                    .opacity(isHovered || isRefreshFocused || queue.refreshID != nil ? 1 : 0)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
        }
        .task(id: queue.refreshID) {
            guard let id = queue.refreshID else { return }

            do {
                try await Task.sleep(for: .seconds(20))
            } catch { return }

            queue.finishRefreshIfWaiting(id)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        ForEach(queue.entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .lineLimit(1)

                if let season = entry.season, let episode = entry.episode {
                    Text("Season \(season), Episode \(episode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .tag(SidebarSelection.continueWatching(queue.id, entry.id))
            .help(entry.episodeTitle ?? entry.title)
        }

        if queue.responseError {
            Text("Couldn’t refresh. Open \(queue.adapter.name) and select your profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if queue.updatedAt == nil {
            Text("Refresh to load your queue.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if queue.entries.isEmpty {
            Text("Nothing to continue watching.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if queue.storageError {
            Text("Local storage is unavailable. This queue may not be saved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var refreshButton: some View {
        Button {
            model.refreshContinueWatching(queue.id)
        } label: {
            if queue.refreshID != nil {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
        .focused($isRefreshFocused)
        .disabled(model.continueWatchingSite(for: queue.id) == nil || queue.refreshID != nil)
        .help("Refresh \(queue.adapter.name) Continue Watching")
        .accessibilityLabel("Refresh \(queue.adapter.name) Continue Watching")
    }
}
