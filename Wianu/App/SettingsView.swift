import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        GeneralSettingsView(model: model)
            .frame(width: 560, height: 340)
            .onAppear {
                model.settingsOpened()
            }
            .onDisappear { model.settingsClosed() }
    }
}

private struct GeneralSettingsView: View {
    let model: AppModel

    @AppStorage(AnalyticsPreference.enabledKey)
    private var analyticsEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Share Usage Analytics",
                    isOn: Binding(
                        get: { analyticsEnabled },
                        set: { enabled in
                            analyticsEnabled = enabled
                            model.setAnalyticsEnabled(enabled)
                        }
                    )
                )

                Text(
                    "Help improve Wianu by sharing feature usage and service choices. "
                        + "Titles, searches, playback history and streaming URLs stay private."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
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

            Link(destination: SupportPromptModel.supportURL) {
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
