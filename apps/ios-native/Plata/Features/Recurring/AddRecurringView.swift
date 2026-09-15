import SwiftUI

// Crear una suscripción / pago recurrente. Monto grande arriba, selector visual
// de LOGO DE APP (grid scrolleable de SubscriptionLogo.all con su imagen — al
// elegir se rellena el nombre), nombre del servicio, frecuencia con PillToggle,
// categoría, cuenta y próxima fecha de cobro. Guarda vía
// SupabaseClient.shared.insert("recurring_events", …) respetando el esquema del
// modelo RecurringEvent y refresca AppState. Paridad con app/add-recurring RN.

struct AddRecurringView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Namespace private var freqNS

    // Formulario
    @State private var amountDigits = ""
    @State private var name = ""
    @State private var selectedLogo: String?          // slug del catálogo
    @State private var frequency: Frequency = .monthly
    @State private var categoryId: String?
    @State private var accountId: String?
    @State private var nextDate = Date()

    // Presentación
    @State private var showLogoPicker = false
    @State private var showCategoryPicker = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
                Palette.bg.opacity(0.6).ignoresSafeArea()
                content
            }
            .navigationTitle("Nueva suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .glassSheetBackground()
        .onAppear(perform: seedDefaults)
    }

    // MARK: - Contenido

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Space.xl) {
                    logoHeader
                        .padding(.top, Space.m)

                    amountDisplay

                    selectors
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(
                title: isSaving ? "Guardando…" : "Guardar",
                icon: isSaving ? nil : "checkmark",
                tint: canSave ? Palette.accent : Palette.surfaceElevated,
                fg: canSave ? Palette.bg : Palette.inkTertiary
            ) {
                save()
            }
            .disabled(!canSave || isSaving)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.s)
        }
        .sheet(isPresented: $showLogoPicker) {
            RecurrentesLogoPicker(selection: $selectedLogo) { slug in
                // Al elegir logo, si el nombre está vacío se autocompleta.
                if name.trimmingCharacters(in: .whitespaces).isEmpty, let slug {
                    name = RecurrentesLogoName.display(for: slug)
                }
            }
            .presentationDetents([.large])
            .glassSheetBackground()
        }
        .sheet(isPresented: $showCategoryPicker) {
            RecurrentesCategoryPicker(categories: expenseCategories, selection: $categoryId)
                .presentationDetents([.medium, .large])
                .glassSheetBackground()
        }
        .alert("No se pudo guardar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
    }

    // MARK: - Encabezado con logo tappable

    private var logoHeader: some View {
        Button {
            showLogoPicker = true
        } label: {
            VStack(spacing: Space.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.surface)
                        .frame(width: 88, height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: 1)
                        )
                    if let image = SubscriptionLogo.image(for: selectedLogo) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                Text(selectedLogo == nil ? "Elegir logo de la app" : "Cambiar logo")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .pressable()
    }

    // MARK: - Monto

    private var amountDisplay: some View {
        VStack(spacing: Space.s) {
            Text("MONTO")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.inkTertiary)

            HStack(spacing: Space.s) {
                Image(systemName: "minus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.inkTertiary)
                    .opacity(amountValue > 0 ? 1 : 0)

                Text(formattedAmount)
                    .font(Typo.amountHero(amountFontSize))
                    .monospacedDigit()
                    .tracking(-0.5) // tracking negativo sutil en cifra display grande
                    .foregroundStyle(amountValue > 0 ? Palette.ink : Palette.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText(value: amountValue))
                    .animation(Motion.value, value: amountValue)
            }

            RecurrentesKeypad { key in tap(key) }
                .padding(.top, Space.s)
        }
    }

    // MARK: - Selectores

    private var selectors: some View {
        VStack(spacing: Space.m) {
            // Nombre del servicio
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: "textformat", tint: Palette.orange)
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("Ej. Netflix, Spotify, Arriendo").foregroundColor(Palette.inkTertiary)
                    )
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .submitLabel(.done)
                }
            }

            // Frecuencia
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Frecuencia")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.leading, Space.xs)
                PillToggle(options: freqOptions, selection: $frequency, namespace: freqNS)
            }

            // Categoría
            Button {
                showCategoryPicker = true
            } label: {
                RecurrentesSelectorRow(
                    leading: {
                        if let cat = selectedCategory {
                            CategoryIcon(
                                systemName: TransactionVisual.symbol(for: cat, fallbackType: .expense),
                                color: TransactionVisual.color(for: cat),
                                size: 36
                            )
                        } else {
                            RecurrentesSmallIcon(symbol: "square.grid.2x2", tint: Palette.accent)
                        }
                    },
                    label: "Categoría",
                    value: selectedCategory?.name ?? "Seleccionar"
                )
            }
            .pressable()
            .disabled(expenseCategories.isEmpty)

            // Cuenta (opcional)
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: selectedAccount?.type.sfSymbol ?? "creditcard", tint: Palette.sky)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cuenta")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        Text(selectedAccount?.name ?? "Sin asignar")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !app.accounts.isEmpty {
                        Menu {
                            Button("Sin asignar") { accountId = nil }
                            ForEach(app.accounts) { acc in
                                Button(acc.name) { accountId = acc.id }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
            }

            // Próxima fecha de cobro
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    RecurrentesSmallIcon(symbol: "calendar", tint: Palette.purple)
                    Text("Próximo cobro")
                        .font(Typo.callout)
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    DatePicker("", selection: $nextDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Palette.accent)
                }
            }
        }
    }

    // MARK: - Teclado

    private func tap(_ key: RecurrentesKeypadKey) {
        switch key {
        case .digit(let d):
            guard amountDigits.count < 12 else { return }
            if amountDigits.isEmpty && d == "0" { return }
            amountDigits.append(d)
        case .delete:
            if !amountDigits.isEmpty { amountDigits.removeLast() }
        case .clear:
            amountDigits = ""
        }
    }

    // MARK: - Guardar

    private func save() {
        guard canSave, let hh = app.household?.id else { return }
        isSaving = true
        saveError = nil

        struct Insert: Encodable {
            let household_id: String
            let name: String
            let amount: Double
            let frequency: String
            let next_date: String
            let category_id: String?
            let account_id: String?
            let is_active: Bool
        }

        // El nombre guardado prioriza el del logo (para poder mapearlo al listar).
        let finalName = name.trimmingCharacters(in: .whitespaces)
        let insert = Insert(
            household_id: hh,
            name: finalName,
            amount: amountValue,
            frequency: frequency.rawValue,
            next_date: RecurrentesDate.iso(nextDate),
            category_id: categoryId,
            account_id: accountId,
            is_active: true
        )

        Task {
            do {
                let _: [RecurringEvent] = try await SupabaseClient.shared.insert("recurring_events", values: insert)
                await app.refreshAll()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    // MARK: - Derivados

    private var freqOptions: [(value: Frequency, label: String, tint: Color)] {
        [
            (.monthly, "Mensual", Palette.accent),
            (.weekly, "Semanal", Palette.accent),
            (.yearly, "Anual", Palette.accent),
        ]
    }

    private var amountValue: Double { Double(amountDigits) ?? 0 }

    private var formattedAmount: String {
        CurrencyFormatter.string(amountValue, currency: app.currency)
    }

    private var amountFontSize: CGFloat {
        switch formattedAmount.count {
        case ...9: return 52
        case 10...12: return 42
        case 13...15: return 34
        default: return 28
        }
    }

    private var expenseCategories: [Category] {
        app.categories.filter { $0.type == .expense }
    }

    private var selectedCategory: Category? { app.category(for: categoryId) }

    private var selectedAccount: Account? {
        app.accounts.first { $0.id == accountId }
    }

    private var canSave: Bool {
        amountValue > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty && categoryId != nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func seedDefaults() {
        if categoryId == nil { categoryId = expenseCategories.first?.id }
    }
}

// MARK: - Selector de logo (grid scrolleable del catálogo)

struct RecurrentesLogoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String?
    var onSelect: (String?) -> Void = { _ in }

    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Space.m)]

    private var filtered: [String] {
        let q = search
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return SubscriptionLogo.all }
        return SubscriptionLogo.all.filter { $0.contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        noneCell
                        ForEach(filtered, id: \.self) { slug in
                            logoCell(slug)
                        }
                    }
                    .padding(Space.l)
                }
            }
            .searchable(text: $search, prompt: "Buscar app")
            .navigationTitle("Elegir logo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }

    private var noneCell: some View {
        Button {
            selection = nil
            onSelect(nil)
            dismiss()
        } label: {
            VStack(spacing: Space.s) {
                Image(systemName: "nosign")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 48, height: 48)
                Text("Ninguno")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(selection == nil ? Palette.accent : Palette.stroke, lineWidth: selection == nil ? 1.5 : 1)
            )
        }
        .pressable()
    }

    private func logoCell(_ slug: String) -> some View {
        let isSelected = selection == slug
        return Button {
            selection = slug
            onSelect(slug)
            dismiss()
        } label: {
            VStack(spacing: Space.s) {
                if let image = SubscriptionLogo.image(for: slug) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(width: 40, height: 40)
                }
                Text(RecurrentesLogoName.display(for: slug))
                    .font(Typo.caption)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .pressable()
    }
}

// MARK: - Picker de categoría (reutilizado por add y edit)

struct RecurrentesCategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    @Binding var selection: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Space.m)]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.opacity(0.6).ignoresSafeArea()
                if categories.isEmpty {
                    VStack(spacing: Space.s) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.inkTertiary)
                        Text("No hay categorías de gasto")
                            .font(Typo.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Space.m) {
                            ForEach(categories) { cat in
                                Button {
                                    selection = cat.id
                                    dismiss()
                                } label: {
                                    cell(cat)
                                }
                                .pressable()
                            }
                        }
                        .padding(Space.l)
                    }
                }
            }
            .navigationTitle("Categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }.foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
    }

    private func cell(_ cat: Category) -> some View {
        let isSelected = selection == cat.id
        let color = TransactionVisual.color(for: cat)
        return VStack(spacing: Space.s) {
            CategoryIcon(
                systemName: TransactionVisual.symbol(for: cat, fallbackType: .expense),
                color: color,
                size: 48
            )
            Text(cat.name)
                .font(Typo.caption)
                .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(isSelected ? color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Subcomponentes de la feature

struct RecurrentesSmallIcon: View {
    let symbol: String
    var tint: Color = Palette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            // Radio 36*0.32 = concéntrico con CategoryIcon(size:36) al intercambiarse.
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11.5, style: .continuous))
    }
}

struct RecurrentesSelectorRow<Leading: View>: View {
    @ViewBuilder var leading: () -> Leading
    let label: String
    let value: String

    var body: some View {
        Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                leading()
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                    Text(value)
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

// MARK: - Teclado numérico propio

enum RecurrentesKeypadKey: Hashable {
    case digit(String)
    case delete
    case clear
}

struct RecurrentesKeypad: View {
    var onTap: (RecurrentesKeypadKey) -> Void

    private let rows: [[RecurrentesKeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    var body: some View {
        VStack(spacing: Space.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        Button { onTap(key) } label: {
                            content(for: key)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .foregroundStyle(foreground(for: key))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .contentShape(Rectangle())
                        }
                        .pressable(scale: 0.94)
                    }
                }
            }
        }
    }

    @ViewBuilder private func content(for key: RecurrentesKeypadKey) -> some View {
        switch key {
        case .digit(let d): Text(d).monospacedDigit()
        case .delete: Image(systemName: "delete.left")
        case .clear: Image(systemName: "xmark")
        }
    }

    private func foreground(for key: RecurrentesKeypadKey) -> Color {
        switch key {
        case .digit: return Palette.ink
        case .delete: return Palette.inkSecondary
        case .clear: return Palette.inkTertiary
        }
    }
}

// MARK: - Nombre legible a partir de un slug del catálogo

enum RecurrentesLogoName {
    static func display(for slug: String) -> String {
        // Casos especiales del catálogo.
        let special: [String: String] = [
            "disney-": "Disney+", "paramount-": "Paramount+", "playstation-": "PlayStation",
            "hbo-max": "HBO Max", "the-new-york-times": "New York Times",
            "the-economist": "The Economist", "google-one": "Google One",
            "google-play": "Google Play", "youtube-music": "YouTube Music",
            "amazon-music": "Amazon Music", "apple-music": "Apple Music",
            "apple-arcade": "Apple Arcade", "appletv": "Apple TV",
            "prime-video": "Prime Video", "office-365": "Office 365",
            "mercado-libre": "Mercado Libre", "nintendo-online": "Nintendo Online",
            "adobe-cloud": "Adobe Cloud", "x": "X", "n8n": "n8n", "v0": "v0",
        ]
        if let s = special[slug] { return s }
        return slug
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

extension RecurrentesDate {
    static func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
