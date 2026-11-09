import SwiftUI

struct SiteEditorView: View {
    enum Mode {
        case add
        case edit(SavedSite)

        var title: String {
            switch self {
            case .add: "Add Site"
            case .edit: "Edit Site"
            }
        }

        var message: String {
            switch self {
            case .add: "Save a website to access it quickly from the sidebar."
            case .edit: "Update the name or website address."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel

    let mode: Mode
    @State private var draft: SiteDraft
    @State private var providers: [TMDBProvider] = []
    @State private var providerLoadError: String?

    init(model: AppModel, mode: Mode) {
        self.model = model
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: SiteDraft())
        case let .edit(site):
            _draft = State(initialValue: SiteDraft(site: site))
            _providers = State(
                initialValue: site.tmdbProviders.map {
                    TMDBProvider(id: $0.id, name: $0.name, logoPath: nil)
                }
            )
        }
    }

    var body: some View {
        NavigationStack {
            editorContent
                .padding(20)
                .frame(minWidth: 520, minHeight: 360, alignment: .topLeading)
                .onChange(of: draft.address) {
                    applySuggestedSearchTemplate()
                }
                .task { await loadProviders() }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: dismiss.callAsFunction)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .keyboardShortcut(.defaultAction)
                            .disabled(draft.validatedValues == nil)
                    }
                }
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            editorHeader
            siteFields

            if let error = model.siteStore.persistenceError {
                Text("Couldn't save this site. \(error)")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.title)
                .font(.title2.weight(.semibold))
            Text(mode.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var siteFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            identityFields
            searchFields
            providerFields
        }
    }

    @ViewBuilder
    private var identityFields: some View {
        field("Name") {
            TextField("Example: Netflix", text: $draft.name)
        }
        field("URL") {
            TextField("example.com", text: $draft.address)
                .autocorrectionDisabled()
        }
        if !draft.address.isEmpty, !draft.siteURLIsValid {
            Text("Enter a valid HTTPS website address.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var searchFields: some View {
        field("Search URL (Optional)") {
            TextField(
                "https://example.com/search?q={query}",
                text: $draft.searchURLTemplate
            )
            .autocorrectionDisabled()
        }
        Text(
            "Use {query} where the movie or show title belongs. "
                + "Leave this empty to hide the site from Search."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        if !draft.searchURLTemplateIsValid {
            Text(
                "Enter a valid HTTPS URL containing "
                    + "exactly one {query} placeholder."
            )
            .font(.caption)
            .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var providerFields: some View {
        field("TMDB Providers (Optional)") {
            TMDBProviderPicker(
                providers: providers,
                selection: $draft.tmdbProviders
            )
        }
        Text(
            providerLoadError
                ?? "Select all providers that should open this site’s configured Search URL."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func field(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content()
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        switch mode {
        case .add:
            guard model.addSite(draft) else { return }

        case let .edit(site):
            guard model.updateSite(site, with: draft) else { return }
        }

        dismiss()
    }

    private func applySuggestedSearchTemplate() {
        guard draft.searchURLTemplate.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty,
              let suggestion = draft.suggestedSearchURLTemplate
        else { return }

        draft.searchURLTemplate = suggestion
    }

    private func loadProviders() async {
        do {
            providers = try await model.tmdbClient.providers()

            for current in draft.tmdbProviders where !providers.contains(where: { $0.id == current.id }) {
                providers.insert(
                    TMDBProvider(
                        id: current.id,
                        name: current.name,
                        logoPath: nil
                    ),
                    at: 0
                )
            }
        } catch {
            providerLoadError = error.localizedDescription
        }
    }
}

private struct TMDBProviderPicker: View {
    let providers: [TMDBProvider]
    @Binding var selection: [TMDBProviderReference]
    @State private var isPresented = false
    @State private var query = ""

    private var filteredProviders: [TMDBProvider] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else { return providers }

        return providers.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack {
                Text(selection.isEmpty ? "Not associated" : selection.map(\.name).joined(separator: ", "))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 8) {
                TextField("Search providers", text: $query)
                    .textFieldStyle(.roundedBorder)

                List {
                    ForEach(filteredProviders) { provider in
                        providerToggle(provider)
                    }
                }
                .listStyle(.plain)

                HStack {
                    Button("Clear All") { selection.removeAll() }
                        .disabled(selection.isEmpty)

                    Spacer()

                    Button("Done") { isPresented = false }
                }
            }
            .padding(12)
            .frame(width: 320, height: 360)
        }
    }

    private func providerToggle(_ provider: TMDBProvider) -> some View {
        Toggle(provider.name, isOn: Binding(
            get: { selection.contains(where: { $0.id == provider.id }) },
            set: { isSelected in
                if isSelected {
                    selection.append(TMDBProviderReference(id: provider.id, name: provider.name))
                } else {
                    selection.removeAll { $0.id == provider.id }
                }
            }
        ))
        .toggleStyle(.checkbox)
    }
}
