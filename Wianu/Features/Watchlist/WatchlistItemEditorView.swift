import SwiftUI

struct WatchlistItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let item: WatchlistItem?
    let onSave: (String, Int?, URL?) -> Void

    @State private var title: String
    @State private var year: String
    @State private var urlString: String

    init(
        item: WatchlistItem? = nil,
        onSave: @escaping (String, Int?, URL?) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _year = State(initialValue: item?.year.map(String.init) ?? "")
        _urlString = State(initialValue: item?.url?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                heading
                fields
                Spacer()
            }
            .padding(20)
            .frame(minWidth: 500, minHeight: 330, alignment: .topLeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item == nil ? "Add Movie" : "Edit Movie")
                .font(.title2.weight(.semibold))
            Text("Only the title is required. Add a link to open the movie directly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            field("Title") {
                TextField("Movie title", text: $title)
            }
            field("Year (Optional)") {
                TextField("2026", text: $year)
            }
            field("Link (Optional)") {
                TextField("https://example.com/movie", text: $urlString)
                    .autocorrectionDisabled()
            }

            if !yearIsValid {
                validationMessage("Enter a four-digit year.")
            }
            if !urlIsValid {
                validationMessage("Enter a valid HTTPS link.")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedYear: String {
        year.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedYear: Int? {
        Int(trimmedYear)
    }

    private var yearIsValid: Bool {
        trimmedYear.isEmpty
            || (trimmedYear.count == 4
                && parsedYear.map { (1888 ... 2100).contains($0) } == true)
    }

    private var trimmedURLString: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedURL: URL? {
        guard !trimmedURLString.isEmpty else { return nil }

        let value = trimmedURLString.contains("://")
            ? trimmedURLString
            : "https://\(trimmedURLString)"

        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host() != nil,
              url.user() == nil,
              url.password() == nil
        else { return nil }

        return url
    }

    private var urlIsValid: Bool {
        trimmedURLString.isEmpty || parsedURL != nil
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty && yearIsValid && urlIsValid
    }

    private func field(
        _ label: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
            content()
                .textFieldStyle(.roundedBorder)
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func save() {
        guard isValid else { return }
        onSave(trimmedTitle, parsedYear, parsedURL)
        dismiss()
    }
}
