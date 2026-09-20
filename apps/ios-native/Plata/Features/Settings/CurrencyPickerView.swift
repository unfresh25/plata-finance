import SwiftUI

// Catálogo de todas las monedas ISO 4217 (Foundation) con nombre localizado,
// y una vista de selección con buscador (la lista es larga).

enum CurrencyCatalog {
    static let all: [(code: String, label: String)] = {
        let locale = Locale(identifier: "es")
        return Locale.commonISOCurrencyCodes.map { code in
            (code, locale.localizedString(forCurrencyCode: code) ?? code)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }()

    static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code
    }
}

struct CurrencyPickerView: View {
    let selected: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [(code: String, label: String)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return CurrencyCatalog.all }
        return CurrencyCatalog.all.filter {
            $0.code.lowercased().contains(q) || $0.label.lowercased().contains(q)
        }
    }

    var body: some View {
        List(filtered, id: \.code) { item in
            Button {
                onSelect(item.code)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).foregroundStyle(Palette.ink)
                        Text(item.code).font(Typo.caption).foregroundStyle(Palette.inkTertiary)
                    }
                    Spacer()
                    if item.code == selected {
                        Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Buscar moneda")
        .navigationTitle("Moneda")
        .navigationBarTitleDisplayMode(.inline)
    }
}
