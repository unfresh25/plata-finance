import SwiftUI

// Gestión de categorías. Lista agrupada por tipo (Gastos / Ingresos), cada una
// con su ícono SF (vía IconMapping) teñido de su color. Añadir y editar en un
// sheet con vista previa gigante, paleta de color y selector de ícono. Paridad
// con app/categories.tsx + app/category/[id].tsx de la app RN.

struct CategoriesView: View {
    @Environment(AppState.self) private var app

    @State private var editor: CategorasEditorTarget?

    private var expenses: [Category] {
        app.categories
            .filter { $0.type == .expense }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var incomes: [Category] {
        app.categories
            .filter { $0.type == .income }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                if app.categories.isEmpty {
                    CategorasEmptyState { editor = .new }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.xl) {
                            CategorasSection(
                                title: "Gastos",
                                categories: expenses,
                                onEdit: { editor = .edit($0) }
                            )
                            CategorasSection(
                                title: "Ingresos",
                                categories: incomes,
                                onEdit: { editor = .edit($0) }
                            )
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.top, Space.s)
                        .padding(.bottom, Space.xxxl)
                    }
                }
            }
            .navigationTitle("Categorías")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = .new
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.bg)
                            .frame(width: 32, height: 32)
                            .background(Palette.ink, in: Circle())
                    }
                    .pressable()
                }
            }
            // Header translúcido: el contenido pasa por debajo (Apple §12).
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Palette.accent)
        .sheet(item: $editor) { target in
            CategorasEditorView(target: target)
        }
    }
}

// MARK: - Sección por tipo (Gastos / Ingresos)

private struct CategorasSection: View {
    let title: String
    let categories: [Category]
    let onEdit: (Category) -> Void

    var body: some View {
        PlainSection(title: title) {
            if categories.isEmpty {
                Text("No hay categorías aquí.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.l)
            } else {
                PlainList(categories, dividerInset: 44 + Space.m) { cat in
                    NavigationLink {
                        CategoryDetailView(category: cat, onEdit: { onEdit(cat) })
                    } label: {
                        CategorasRow(category: cat)
                    }
                    .buttonStyle(.plain)
                    .pressable()
                }
            }
        }
    }
}

// MARK: - Fila de categoría

private struct CategorasRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(
                systemName: IconMapping.sfSymbol(for: category.icon),
                color: CategorasVisual.color(for: category),
                size: 44
            )

            Text(category.name)
                .font(Typo.callout)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

            Spacer(minLength: Space.s)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Estado vacío

private struct CategorasEmptyState: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: Space.l) {
            CategoryIcon(systemName: "square.grid.2x2.fill", color: Palette.accent, size: 84)

            VStack(spacing: Space.xs) {
                Text("Aún no hay categorías")
                    .font(Typo.title)
                    .foregroundStyle(Palette.ink)
                Text("Crea categorías para organizar tus gastos e ingresos con color y estilo propios.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xl)
            }

            PrimaryButton(title: "Nueva categoría", icon: "plus", action: onAdd)
                .frame(maxWidth: 260)
                .padding(.top, Space.s)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Target del editor (nueva / editar)

enum CategorasEditorTarget: Identifiable {
    case new
    case edit(Category)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let c): return c.id
        }
    }
}

// MARK: - Editor (nueva / editar categoría)

private struct CategorasEditorView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let target: CategorasEditorTarget

    @State private var name: String
    @State private var type: CategoryType
    @State private var color: String
    @State private var icon: String

    @State private var showingIconPicker = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorText: String?

    init(target: CategorasEditorTarget) {
        self.target = target
        switch target {
        case .new:
            _name = State(initialValue: "")
            _type = State(initialValue: .expense)
            _color = State(initialValue: CategorasVisual.palette[0])
            _icon = State(initialValue: CategorasVisual.iconSlugs[0])
        case .edit(let c):
            _name = State(initialValue: c.name)
            _type = State(initialValue: c.type)
            _color = State(initialValue: c.color.isEmpty ? CategorasVisual.palette[0] : c.color)
            _icon = State(initialValue: c.icon.isEmpty ? CategorasVisual.iconSlugs[0] : c.icon)
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var tint: Color { CategorasVisual.color(hex: color) }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.xxl) {
                        preview
                        typeSelector
                        colorPalette
                        iconButton

                        if let errorText {
                            Text(errorText)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.negative)
                                .multilineTextAlignment(.center)
                        }

                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: Space.s) {
                                    Image(systemName: "trash")
                                    Text("Eliminar categoría").font(Typo.headline)
                                }
                                .foregroundStyle(Palette.negative)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.l)
                                .background(
                                    Palette.negative.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                )
                            }
                            .pressable()
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.xxxl)
                }
            }
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { Task { await save() } }
                        .font(Typo.headline)
                        .foregroundStyle(canSave ? Palette.accent : Palette.inkTertiary)
                        .disabled(!canSave || isSaving)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .sheet(isPresented: $showingIconPicker) {
                CategorasIconPicker(selected: $icon, tint: tint)
            }
            .confirmationDialog(
                "¿Eliminar categoría?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) { Task { await deleteCategory() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Las transacciones asociadas podrían perder su categoría.")
            }
        }
        .tint(Palette.accent)
        .presentationBackground(Palette.bg)
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    // MARK: Vista previa gigante

    private var preview: some View {
        VStack(spacing: Space.l) {
            Button {
                showingIconPicker = true
            } label: {
                Image(systemName: IconMapping.sfSymbol(for: icon))
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 96, height: 96)
                    .background(
                        tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                    )
            }
            .pressable()

            TextField("", text: $name, prompt: Text("Nombre de categoría").foregroundStyle(Palette.inkTertiary))
                .font(Typo.amountMedium)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .tint(tint)
                .textInputAutocapitalization(.words)
        }
        .padding(.top, Space.m)
    }

    // MARK: Tipo (Gasto / Ingreso)

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(text: "Tipo de movimiento")
            HStack(spacing: Space.m) {
                CategorasTypeButton(title: "Gasto", tint: Palette.pink, isSelected: type == .expense) {
                    withAnimation(Motion.ui) { type = .expense }
                }
                CategorasTypeButton(title: "Ingreso", tint: Palette.green, isSelected: type == .income) {
                    withAnimation(Motion.ui) { type = .income }
                }
            }
        }
    }

    // MARK: Paleta de color

    private var colorPalette: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(text: "Color")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    ForEach(CategorasVisual.palette, id: \.self) { hex in
                        let isSelected = hex.caseInsensitiveCompare(color) == .orderedSame
                        Button {
                            withAnimation(Motion.ui) { color = hex }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(CategorasVisual.color(hex: hex))
                                    .frame(width: 44, height: 44)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay(
                                Circle().strokeBorder(Palette.ink, lineWidth: isSelected ? 3 : 0)
                            )
                        }
                        .pressable()
                    }
                }
                .padding(.horizontal, Space.xs)
                .padding(.vertical, Space.xs)
            }
        }
    }

    // MARK: Botón elegir ícono

    private var iconButton: some View {
        Button {
            showingIconPicker = true
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: IconMapping.sfSymbol(for: icon))
                Text("Elegir ícono").font(Typo.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
            .background(tint, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        }
        .pressable()
    }

    // MARK: Guardar

    private func save() async {
        guard canSave, let householdId = app.household?.id else { return }
        isSaving = true
        errorText = nil
        defer { isSaving = false }

        struct Payload: Encodable {
            let household_id: String
            let name: String
            let type: String
            let color: String
            let icon: String
        }
        let payload = Payload(
            household_id: householdId,
            name: trimmedName,
            type: type.rawValue,
            color: color,
            icon: icon
        )

        do {
            switch target {
            case .new:
                let _: [Category] = try await SupabaseClient.shared.insert("categories", values: payload)
            case .edit(let c):
                try await SupabaseClient.shared.update("categories", values: payload, match: ["id": c.id])
            }
            await app.refreshAll()
            dismiss()
        } catch {
            errorText = "No se pudo guardar. Inténtalo de nuevo."
        }
    }

    // MARK: Eliminar

    private func deleteCategory() async {
        guard case .edit(let c) = target else { return }
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        do {
            try await CategorasDelete.remove(id: c.id)
            await app.refreshAll()
            dismiss()
        } catch {
            errorText = "No se pudo eliminar. Inténtalo de nuevo."
        }
    }
}

// MARK: - Botón de tipo

private struct CategorasTypeButton: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.headline)
                .foregroundStyle(isSelected ? .white : Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.l)
                .background(
                    isSelected ? tint : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(isSelected ? .clear : Palette.stroke, lineWidth: 1)
                )
        }
        .pressable()
    }
}

// MARK: - Selector de ícono (grid en sheet)

private struct CategorasIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String
    let tint: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Space.m), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Space.m) {
                        ForEach(CategorasVisual.iconSlugs, id: \.self) { slug in
                            let isSelected = slug == selected
                            Button {
                                selected = slug
                                dismiss()
                            } label: {
                                Image(systemName: IconMapping.sfSymbol(for: slug))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(isSelected ? tint : Palette.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        isSelected ? tint.opacity(0.16) : Palette.surface,
                                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                            .strokeBorder(isSelected ? tint : Palette.stroke, lineWidth: 1)
                                    )
                            }
                            .pressable()
                        }
                    }
                    .padding(Space.l)
                    .padding(.bottom, Space.xxxl)
                }
            }
            .navigationTitle("Seleccionar ícono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationBackground(Palette.bg)
        .presentationDetents([.large])
    }
}

// MARK: - Color / paleta / íconos compartidos por la feature

enum CategorasVisual {
    /// Paleta de colores idéntica a la app RN (app/category/[id].tsx).
    static let palette: [String] = [
        "#EF4444", "#F97316", "#F59E0B", "#84CC16", "#22C55E", "#14B8A6",
        "#06B6D4", "#3B82F6", "#6366F1", "#8B5CF6", "#D946EF", "#F43F5E", "#64748B",
    ]

    /// Slugs de ícono del backend (orden de CategoryIconGroups, sin repetidos),
    /// que se renderizan con IconMapping.sfSymbol(for:).
    static let iconSlugs: [String] = [
        "hamburger-01", "coffee-01", "natural-food", "pizza-01", "drink", "croissant", "candy",
        "taxi", "fuel-station", "bus-01", "airplane-01", "car-01", "motorbike-02", "bicycle", "parking-meter",
        "home-01", "invoice-01", "wifi-02", "wrench-01", "sofa-01", "washing-machine", "paint-brush-02",
        "hospital-01", "medicine-02", "dumbbell-01", "mentoring", "dental-tooth", "glasses", "first-aid-kit",
        "tv-01", "game-controller-01", "theater", "music-note-01", "book-01", "volleyball", "ticket-01",
        "t-shirt", "running-shoes", "watch-01", "smartphone-01", "hair-dryer", "bird", "baby-01",
        "laptop", "mortarboard-01", "notebook-01", "translate", "diploma",
        "money-bag-02", "computer", "chart-increase", "building-02", "star", "exchange-01",
        "credit-card", "piggy-bank", "invoice-02", "shield-01", "bank", "coins-01",
        "hotel-02", "luggage-01", "compass", "passport-01", "gift", "favourite", "repeat", "alert-02", "more-horizontal",
    ]

    static func color(for category: Category) -> Color {
        color(hex: category.color)
    }

    /// Parsea un hex "#RRGGBB" o "RRGGBB"; si falla usa el acento de marca.
    static func color(hex: String?) -> Color {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return Palette.accent
        }
        if s.hasPrefix("#") { s.removeFirst() }
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s.removeFirst(2) }
        guard s.count == 6, let value = UInt(s, radix: 16) else { return Palette.accent }
        return Color(hex: value)
    }
}

// MARK: - Borrado de categoría (REST directo; no existe delete en el cliente)

enum CategorasDelete {
    static func remove(id: String) async throws {
        var comps = URLComponents(
            url: SupabaseConfig.url.appendingPathComponent("/rest/v1/categories"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "DELETE"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = SupabaseClient.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Error al eliminar"
            throw SupabaseError(message: msg)
        }
    }
}
