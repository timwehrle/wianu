import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeneralSettingsView()
            .frame(width: 560, height: 240)
            .onAppear {
                model.settingsOpened()
            }
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(AnalyticsPreference.enabledKey)
    private var analyticsEnabled = true

    var body: some View {
        Form {
            Toggle(
                "Send Anonymous Usage Analytics",
                isOn: $analyticsEnabled
            )

            Text(
                "Share basic feature usage and the Wianu version. "
                    + "A random installation ID links repeat visits. "
                    + "Searches, titles, URLs, providers, and personal "
                    + "identifiers are never included."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                Text("Wianu")
                    .font(.title.weight(.semibold))
                Text("Version \(version) (\(build))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Made by Tim Wehrle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://kofi.com/timwehrle")!) {
                Label("Support My Work", systemImage: "heart")
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(spacing: 10) {
                Image("TMDBLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 28)
                Text(
                    "This product uses the TMDB API but is not endorsed or "
                        + "certified by TMDB."
                )

                Text("Watch-provider availability data by JustWatch.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 360)
    }
}
