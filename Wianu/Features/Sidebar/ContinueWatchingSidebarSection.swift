import SwiftUI

struct ContinueWatchingSidebarSection: View {
    @Bindable var model: AppModel
    @AppStorage("continueWatching.sectionExpanded") private var isExpanded = true

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
    @AppStorage private var isExpanded: Bool
    @State private var isHovered = false
    @FocusState private var isRefreshFocused: Bool

    init(model: AppModel, queue: ContinueWatchingController) {
        self.model = model
        self.queue = queue
        _isExpanded = AppStorage(
            wrappedValue: !queue.entries.isEmpty,
            "continueWatching.\(queue.id.rawValue).expanded"
        )
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

                if queue.responseError || queue.storageError {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(queue.responseError ? "Refresh failed" : "Queue could not be saved")
                }

                if !isExpanded, !queue.entries.isEmpty {
                    Text(queue.entries.count, format: .number)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(queue.entries.count) titles")
                }

                refreshButton
                    .opacity(isHovered || isRefreshFocused || queue.refreshID != nil ? 1 : 0)
            }
            .contentShape(.rect)
            .onHover { isHovered = $0 }
        }
        .help(serviceHelp)
        .contextMenu {
            Button("Refresh") {
                model.refreshContinueWatching(queue.id)
            }
            .disabled(model.continueWatchingSite(for: queue.id) == nil || queue.refreshID != nil)

            Button("Open Service") {
                if let site = model.continueWatchingSite(for: queue.id) {
                    model.select(.site(site.id))
                }
            }
            .disabled(model.continueWatchingSite(for: queue.id) == nil)
        }
    }

    private var serviceHelp: String {
        if queue.responseError {
            return "Couldn’t refresh. Open \(queue.adapter.name) and select your profile."
        }

        if queue.storageError {
            return "Local storage is unavailable. This queue may not be saved."
        }

        guard let updatedAt = queue.updatedAt else { return "Refresh to load your queue." }

        return "Last updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
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
