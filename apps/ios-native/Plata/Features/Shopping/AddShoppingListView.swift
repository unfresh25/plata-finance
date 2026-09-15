import SwiftUI

// Crear una nueva lista de compra. Paridad con add-shopping-list.tsx original:
// presupuesto estimado GIGANTE (hero, teclado propio), nombre, tienda opcional y
// categoría de la lista. Persiste en "shopping_lists" vía SupabaseClient y
// refresca AppState. Estética Plata: dark, elegante, color con propósito.

struct AddShoppingListView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    // Estado del formulario (campos exactos del original)
    @State private var name = ""
    @State private var store = ""
    @State private var budgetDigits = ""       // presupuesto estimado, solo dígitos
    @State private var categoryId: String?

    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: Space.xl) {
                            budgetHero
                                .padding(.top, Space.m)

                            formCard
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.l)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    keypad

                    PrimaryButton(
                        title: isSaving ? "Creando…" : "Crear lista",
                        icon: isSaving ? nil : "cart.badge.plus",
                        tint: canSave ? Palette.sky : Palette.surfaceElevated,
                        fg: canSave ? Palette.bg : Palette.inkTertiary
                    ) {
                        save()
                    }
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.m)
                    .padding(.bottom, Space.s)
                }
            }
            .navigationTitle("Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .alert("No se pudo crear", isPresented: errorBinding) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(saveError ?? "Inténtalo de nuevo.")
            }
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
    }

    // MARK: - Presupuesto hero

    private var budgetHero: some View {
        VStack(spacing: Space.xs) {
            Text("PRESUPUESTO ESTIMADO")
                .font(Typo.overline)
                .tracking(1.2)
                .foregroundStyle(Palette.sky)

            Text(formattedBudget)
                .font(Typo.amountHero(budgetFontSize))
                .monospacedDigit()
                .foregroundStyle(budgetValue > 0 ? Palette.ink : Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: budgetValue))
                .animation(Motion.value, value: budgetValue)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Formulario

    private var formCard: some View {
        VStack(spacing: Space.l) {
            // Nombre de la lista
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    ComprasFieldIcon(symbol: "cart.fill", tint: Palette.sky)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Nombre de la lista")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        TextField(
                            "",
                            text: $name,
                            prompt: Text("Ej. Mercado semanal").foregroundColor(Palette.inkTertiary)
                        )
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .submitLabel(.next)
                    }
                }
            }

            // Tienda / lugar (opcional)
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    ComprasFieldIcon(symbol: "storefront.fill", tint: Palette.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tienda o lugar (opcional)")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        TextField(
                            "",
                            text: $store,
                            prompt: Text("Ej. Éxito, D1, Carulla…").foregroundColor(Palette.inkTertiary)
                        )
                        .font(Typo.callout)
                        .foregroundStyle(Palette.ink)
                        .submitLabel(.done)
                    }
                }
            }

            // Categoría de la lista
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel(text: "Categoría de la lista")
                if expenseCategories.isEmpty {
                    Text("Aún no hay categorías de gasto.")
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.vertical, Space.s)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.s) {
                            ForEach(expenseCategories) { cat in
                                ComprasCategoryChip(
                                    category: cat,
                                    isSelected: categoryId == cat.id
                                ) {
                                    withAnimation(Motion.ui) {
                                        categoryId = (categoryId == cat.id) ? nil : cat.id
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Teclado numérico propio

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        ComprasKeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
    }

    private let keypadRows: [[ComprasKeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    private func tap(_ key: ComprasKeypadKey) {
        switch key {
        case .digit(let d):
            guard budgetDigits.count < 12 else { return }
            if budgetDigits.isEmpty && d == "0" { return }
            budgetDigits.append(d)
        case .delete:
            if !budgetDigits.isEmpty { budgetDigits.removeLast() }
        case .clear:
            budgetDigits = ""
        }
    }

    // MARK: - Guardar

    private func save() {
        guard canSave, let hh = app.household?.id, let uid = app.profile?.id else { return }
        isSaving = true
        saveError = nil

        struct Insert: Encodable {
            let household_id: String
            let created_by: String
            let name: String
            let store: String?
            let category_id: String?
            let estimated_total: Double?
            let status: String
        }
        let payload = Insert(
            household_id: hh,
            created_by: uid,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            store: store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : store.trimmingCharacters(in: .whitespacesAndNewlines),
            category_id: categoryId,
            estimated_total: budgetValue > 0 ? budgetValue : nil,
            status: "open"
        )

        Task {
            do {
                let _: [ShoppingList] = try await SupabaseClient.shared.insert("shopping_lists", values: payload)
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

    private var budgetValue: Double { Double(budgetDigits) ?? 0 }

    private var formattedBudget: String {
        CurrencyFormatter.string(budgetValue, currency: app.currency)
    }

    private var budgetFontSize: CGFloat {
        switch formattedBudget.count {
        case ...9: return 56
        case 10...12: return 46
        case 13...15: return 38
        default: return 30
        }
    }

    private var expenseCategories: [Category] {
        app.categories.filter { $0.type == .expense }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }
}

// MARK: - Chip de categoría

private struct ComprasCategoryChip: View {
    let category: Category
    let isSelected: Bool
    var action: () -> Void

    private var color: Color {
        Color(hexString: category.color) ?? Palette.sky
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Image(systemName: IconMapping.sfSymbol(for: category.icon))
                    .font(.system(size: 13, weight: .semibold))
                Text(category.name)
                    .font(Typo.callout)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? color : Palette.inkSecondary)
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(
                (isSelected ? color.opacity(0.16) : Palette.surface),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? color : Palette.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .pressable()
    }
}

// MARK: - Ícono de campo

private struct ComprasFieldIcon: View {
    let symbol: String
    var tint: Color = Palette.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Teclado: modelo y botón (prefijo único de feature)

enum ComprasKeypadKey: Hashable {
    case digit(String)
    case delete
    case clear
}

struct ComprasKeypadButton: View {
    let key: ComprasKeypadKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .pressable(scale: 0.94)
    }

    @ViewBuilder private var content: some View {
        switch key {
        case .digit(let d): Text(d).monospacedDigit()
        case .delete: Image(systemName: "delete.left")
        case .clear: Image(systemName: "xmark")
        }
    }

    private var foreground: Color {
        switch key {
        case .digit: return Palette.ink
        case .delete: return Palette.inkSecondary
        case .clear: return Palette.inkTertiary
        }
    }
}
