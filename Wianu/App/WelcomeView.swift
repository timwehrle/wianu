import SwiftUI

struct WelcomeView: View {
    let model: AppModel
    let onFinish: () -> Void

    @State private var selectedAddresses: Set<String> = []
    @State private var showingAddSite = false
    @State private var choosingServices = false

    static let services: [SiteDraft] = [
        SiteDraft(
            name: "Netflix",
            address: "https://www.netflix.com",
            tmdbProviders: [TMDBProviderReference(id: 8, name: "Netflix")]
        ),
        SiteDraft(
            name: "Disney+",
            address: "https://www.disneyplus.com",
            tmdbProviders: [TMDBProviderReference(id: 337, name: "Disney Plus")]
        ),
        SiteDraft(
            name: "Prime Video",
            address: "https://www.primevideo.com",
            tmdbProviders: [TMDBProviderReference(id: 9, name: "Amazon Prime Video")]
        ),
        SiteDraft(
            name: "Apple TV",
            address: "https://tv.apple.com",
            tmdbProviders: [TMDBProviderReference(id: 350, name: "Apple TV")]
        )
    ]

    var body: some View {
        VStack(spacing: 32) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text(choosingServices ? "Add Your Services" : "Welcome to Wianu")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if choosingServices {
                serviceSelection
            } else {
                introduction
            }

            VStack(spacing: 12) {
                Button(choosingServices ? "Add Services" : "Continue") {
                    if choosingServices {
                        addServices()
                    } else {
                        choosingServices = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(choosingServices && selectedAddresses.isEmpty)

                Button("Set Up Later", action: onFinish)
                    .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 40)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, minHeight: 620)
        .sheet(isPresented: $showingAddSite) {
            SiteEditorView(model: model, mode: .add)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 28) {
            feature(
                "Your Streaming Services",
                systemImage: "play.rectangle",
                description: "Open your streaming websites from one sidebar."
            )
            feature(
                "Continue Watching",
                systemImage: "play.circle",
                description: "Save a show’s page to return to it later."
            )
            feature(
                "Your Watchlist",
                systemImage: "bookmark",
                description: "Keep movies for later or import your Letterboxd watchlist."
            )
        }
    }

    private func feature(
        _ title: String,
        systemImage: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var serviceSelection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose the websites you use. You can add more at any time.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Self.services, id: \.address) { service in
                    serviceToggle(service)
                }
            }

            Divider()

            Button("Add Other Website…") { showingAddSite = true }

            Text("Sign in on each service’s website after adding it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = model.siteStore.persistenceError {
                Text("Couldn’t save your services. \(error)")
                    .foregroundStyle(.red)
            }
        }
    }

    private func serviceToggle(_ service: SiteDraft) -> some View {
        let isAdded = model.siteStore.sites.contains {
            $0.url?.host() == URL(string: service.address)?.host()
        }

        return Toggle(isOn: Binding(
            get: { isAdded || selectedAddresses.contains(service.address) },
            set: { isSelected in
                if isSelected {
                    selectedAddresses.insert(service.address)
                } else {
                    selectedAddresses.remove(service.address)
                }
            }
        )) {
            HStack(spacing: 8) {
                FaviconView(url: URL(string: service.address))
                    .accessibilityHidden(true)

                Text(service.name)

                if isAdded {
                    Text("Added").foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
        .disabled(isAdded)
    }

    private func addServices() {
        for service in Self.services where selectedAddresses.contains(service.address) {
            guard !model.siteStore.sites.contains(where: {
                $0.url?.host() == URL(string: service.address)?.host()
            }) else { continue }

            var draft = service
            draft.searchURLTemplate = draft.suggestedSearchURLTemplate ?? ""
            model.addSite(draft)

            guard model.siteStore.persistenceError == nil else { return }
        }

        onFinish()
    }
}
