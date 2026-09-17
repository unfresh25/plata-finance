import SwiftUI

// Detalle completo de una lista de compra (paridad con shopping-list/[id].tsx):
// ítems chequeables con cantidad/unidad/precio, marcar comprado pide el precio
// real vía sheet, agregar ítem (nombre, cantidad, unidad, precio estimado),
// total estimado vs real, progreso de comprados y guardar como plantilla.
// Persiste en "shopping_items" y "shopping_templates" vía SupabaseClient.

struct ShoppingListDetailView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    // Copia editable de la lista: nombre y presupuesto pueden cambiar in-place.
    @State private var list: ShoppingList

    init(list: ShoppingList) {
        _list = State(initialValue: list)
    }

    @State private var items: [ShoppingItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    // Añadir ítem rápido
    @State private var newItemName = ""
    @State private var isAddingItem = false

    // Sheets / modales
    @State private var showAddItemSheet = false
    @State private var editItem: ShoppingItem?            // ítem que se está editando
    @State private var priceItem: ShoppingItem?          // ítem que se está marcando comprado
    @State private var showEditListSheet = false
    @State private var showDeleteListAlert = false
    @State private var deleteItemTarget: ShoppingItem?   // ítem pendiente de confirmar borrado
    @State private var showTemplateSaved = false
    @State private var actionError: String?

    private var tint: Color { ShoppingStatusStyle.tint(for: list.status) }

    private var expenseCategories: [Category] {
        app.categories.filter { $0.type == .expense }
    }

    private func category(for id: String?) -> Category? {
        guard let id else { return nil }
        return app.categories.first { $0.id == id }
    }

    // MARK: Derivados

    private var checkedCount: Int { items.filter(\.isChecked).count }

    /// Total estimado: suma de precio estimado × cantidad de todos los ítems.
    private var estimatedTotal: Double {
        items.reduce(0) { $0 + ($1.estimatedPrice ?? 0) * $1.quantity }
    }

    /// Total real: suma del precio real × cantidad de los ítems ya comprados.
    private var actualTotal: Double {
        items.filter(\.isChecked).reduce(0) { $0 + ($1.actualPrice ?? 0) * $1.quantity }
    }

    private var progress: Double {
        items.isEmpty ? 0 : Double(checkedCount) / Double(items.count)
    }

    private var isOverBudget: Bool {
        guard let budget = list.estimatedTotal, budget > 0 else { return false }
        return actualTotal > budget
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                summaryCard

                if isLoading {
                    ShoppingDetailLoading()
                        .padding(.top, Space.xl)
                } else if items.isEmpty {
                    ShoppingDetailEmptyState(failed: loadFailed)
                        .padding(.top, Space.xl)
                } else {
                    SectionLabel(text: "Ítems")
                    VStack(spacing: Space.s) {
                        ForEach(items) { item in
                            ShoppingItemRow(
                                item: item,
                                category: category(for: item.categoryId),
                                currency: app.currency,
                                tint: tint,
                                onToggle: { toggle(item) },
                                onEdit: { editItem = item },
                                onDelete: { deleteItemTarget = item }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.l)
        }
        .floatingTabBarInset()
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddItemSheet = true
                    } label: {
                        Label("Añadir ítem con detalle", systemImage: "plus.circle")
                    }
                    Button {
                        showEditListSheet = true
                    } label: {
                        Label("Editar lista", systemImage: "pencil")
                    }
                    Button {
                        saveAsTemplate()
                    } label: {
                        Label("Guardar como plantilla", systemImage: "square.and.arrow.down")
                    }
                    .disabled(items.isEmpty)
                    Divider()
                    Button(role: .destructive) {
                        showDeleteListAlert = true
                    } label: {
                        Label("Eliminar lista", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            quickAddBar
        }
        .task { await load() }
        .sheet(isPresented: $showAddItemSheet) {
            ShoppingItemEditSheet(
                title: "Nuevo ítem",
                confirmLabel: "Añadir ítem",
                existing: nil,
                categories: expenseCategories,
                currency: app.currency,
                tint: tint
            ) { name, quantity, unit, estimated, categoryId in
                await addDetailedItem(name: name, quantity: quantity, unit: unit, estimated: estimated, categoryId: categoryId)
            }
            .presentationDetents([.large])
            .presentationBackground(Palette.bg)
        }
        .sheet(item: $editItem) { item in
            ShoppingItemEditSheet(
                title: "Editar ítem",
                confirmLabel: "Guardar ítem",
                existing: item,
                categories: expenseCategories,
                currency: app.currency,
                tint: tint
            ) { name, quantity, unit, estimated, categoryId in
                await updateItem(item, name: name, quantity: quantity, unit: unit, estimated: estimated, categoryId: categoryId)
            }
            .presentationDetents([.large])
            .presentationBackground(Palette.bg)
        }
        .sheet(isPresented: $showEditListSheet) {
            ShoppingListEditSheet(
                name: list.name,
                budget: list.estimatedTotal,
                currency: app.currency,
                tint: tint
            ) { newName, newBudget in
                await editList(name: newName, budget: newBudget)
            }
            .presentationDetents([.large])
            .presentationBackground(Palette.bg)
        }
        .sheet(item: $priceItem) { item in
            ShoppingPriceSheet(item: item, currency: app.currency, tint: tint) { realPrice in
                await confirmPurchase(item, realPrice: realPrice)
            }
            .presentationDetents([.height(360)])
            .presentationBackground(Palette.bg)
        }
        .alert("Plantilla guardada", isPresented: $showTemplateSaved) {
            Button("Listo", role: .cancel) {}
        } message: {
            Text("Podrás reutilizar esta lista al crear una nueva.")
        }
        .alert("Algo salió mal", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(actionError ?? "Inténtalo de nuevo.")
        }
        .alert("Eliminar ítem", isPresented: deleteItemBinding, presenting: deleteItemTarget) { item in
            Button("Cancelar", role: .cancel) { deleteItemTarget = nil }
            Button("Eliminar", role: .destructive) {
                Task { await deleteItem(item) }
            }
        } message: { item in
            Text("¿Eliminar “\(item.name)” de la lista?")
        }
        .alert("Eliminar lista", isPresented: $showDeleteListAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task { await deleteList() }
            }
        } message: {
            Text("Se eliminará “\(list.name)” y todos sus ítems. Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Tarjeta resumen (totales + progreso)

    private var summaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: Space.s) {
                    ShoppingStatusBadge(status: list.status)
                    if let store = list.store, !store.isEmpty {
                        Label(store, systemImage: "storefront")
                            .labelStyle(.titleAndIcon)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !items.isEmpty {
                        Text("\(checkedCount)/\(items.count)")
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                if !items.isEmpty {
                    ShoppingProgressBar(progress: progress, tint: tint)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimado")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        Text(CurrencyFormatter.string(estimatedTotal, currency: app.currency))
                            .font(Typo.amountMedium)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(list.estimatedTotal != nil ? "Real / Presup." : "Real")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                        HStack(spacing: 4) {
                            Text(CurrencyFormatter.string(actualTotal, currency: app.currency))
                                .font(Typo.amountMedium)
                                .monospacedDigit()
                                .foregroundStyle(isOverBudget ? Palette.negative : tint)
                            if let budget = list.estimatedTotal, budget > 0 {
                                Text("/ \(CurrencyFormatter.compact(budget))")
                                    .font(Typo.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                }

                if isOverBudget {
                    Label("Te pasaste del presupuesto", systemImage: "exclamationmark.triangle.fill")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.negative)
                }
            }
        }
    }

    // MARK: - Barra de añadir rápido

    private var quickAddBar: some View {
        HStack(spacing: Space.s) {
            TextField(
                "",
                text: $newItemName,
                prompt: Text("Nuevo ítem…").foregroundColor(Palette.inkTertiary)
            )
            .font(Typo.body)
            .foregroundStyle(Palette.ink)
            .submitLabel(.done)
            .onSubmit { quickAdd() }
            .padding(.horizontal, Space.m)
            .frame(height: 48)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )

            Button {
                quickAdd()
            } label: {
                Image(systemName: isAddingItem ? "hourglass" : "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(canQuickAdd ? Palette.bg : Palette.inkTertiary)
                    .frame(width: 48, height: 48)
                    .background(
                        (canQuickAdd ? tint : Palette.surfaceElevated),
                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    )
            }
            .disabled(!canQuickAdd || isAddingItem)
            .pressable(scale: 0.92)
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.stroke.opacity(0.6)).frame(height: 1)
        }
    }

    private var canQuickAdd: Bool {
        !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Carga

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            let fetched = try await Repository().fetchShoppingItems(list: list.id)
            items = fetched.sorted { $0.id < $1.id }
        } catch {
            loadFailed = true
            items = []
        }
        isLoading = false
    }

    // MARK: - Toggle comprado (con precio real vía sheet)

    private func toggle(_ item: ShoppingItem) {
        if item.isChecked {
            // Desmarcar directamente.
            Task { await setChecked(item, checked: false, realPrice: nil) }
        } else {
            // Marcar comprado: pedir el precio real.
            priceItem = item
        }
    }

    private func confirmPurchase(_ item: ShoppingItem, realPrice: Double?) async {
        let finalPrice = realPrice ?? item.estimatedPrice ?? 0
        await setChecked(item, checked: true, realPrice: finalPrice)
    }

    private func setChecked(_ item: ShoppingItem, checked: Bool, realPrice: Double?) async {
        // Optimista.
        applyLocal(item.id) {
            $0.isChecked = checked
            if checked, let realPrice { $0.actualPrice = realPrice }
        }

        struct Patch: Encodable {
            let is_checked: Bool
            let actual_price: Double?
        }
        do {
            try await SupabaseClient.shared.update(
                "shopping_items",
                values: Patch(is_checked: checked, actual_price: checked ? realPrice : nil),
                match: ["id": item.id]
            )
        } catch {
            // Revertir si falla.
            applyLocal(item.id) {
                $0.isChecked = item.isChecked
                $0.actualPrice = item.actualPrice
            }
            actionError = error.localizedDescription
        }
    }

    // MARK: - Añadir ítem rápido (solo nombre)

    private func quickAdd() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAddingItem else { return }
        newItemName = ""
        Task { await addDetailedItem(name: trimmed, quantity: 1, unit: nil, estimated: nil) }
    }

    // MARK: - Añadir ítem con detalle

    private func addDetailedItem(name: String, quantity: Double, unit: String?, estimated: Double?, categoryId: String? = nil) async {
        guard let uid = app.profile?.id else { return }
        isAddingItem = true
        defer { isAddingItem = false }

        struct Insert: Encodable {
            let list_id: String
            let name: String
            let quantity: Double
            let unit: String?
            let estimated_price: Double?
            let is_checked: Bool
            let added_by: String
            let category_id: String?
        }
        let payload = Insert(
            list_id: list.id,
            name: name,
            quantity: quantity,
            unit: unit,
            estimated_price: estimated,
            is_checked: false,
            added_by: uid,
            category_id: categoryId
        )
        do {
            let created: [ShoppingItem] = try await SupabaseClient.shared.insert("shopping_items", values: payload)
            if let item = created.first {
                withAnimation(Motion.ui) {
                    if !items.contains(where: { $0.id == item.id }) { items.append(item) }
                    items.sort { $0.id < $1.id }
                }
            } else {
                await load()
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Editar ítem

    private func updateItem(_ item: ShoppingItem, name: String, quantity: Double, unit: String?, estimated: Double?, categoryId: String?) async {
        // Optimista.
        applyLocal(item.id) {
            $0.name = name
            $0.quantity = quantity
            $0.unit = unit
            $0.estimatedPrice = estimated
            $0.categoryId = categoryId
        }

        struct Patch: Encodable {
            let name: String
            let quantity: Double
            let unit: String?
            let estimated_price: Double?
            let category_id: String?
        }
        do {
            try await SupabaseClient.shared.update(
                "shopping_items",
                values: Patch(name: name, quantity: quantity, unit: unit, estimated_price: estimated, category_id: categoryId),
                match: ["id": item.id]
            )
        } catch {
            // Revertir al valor previo si falla.
            applyLocal(item.id) {
                $0.name = item.name
                $0.quantity = item.quantity
                $0.unit = item.unit
                $0.estimatedPrice = item.estimatedPrice
                $0.categoryId = item.categoryId
            }
            actionError = error.localizedDescription
        }
    }

    // MARK: - Eliminar ítem

    private func deleteItem(_ item: ShoppingItem) async {
        deleteItemTarget = nil
        let snapshot = items
        withAnimation(Motion.ui) { items.removeAll { $0.id == item.id } }
        do {
            try await SupabaseClient.shared.deleteRow("shopping_items", match: ["id": item.id])
        } catch {
            withAnimation(Motion.ui) { items = snapshot }
            actionError = error.localizedDescription
        }
    }

    // MARK: - Editar lista

    private func editList(name: String, budget: Double?) async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let previousName = list.name
        let previousBudget = list.estimatedTotal
        // Optimista local.
        list.name = cleanName
        list.estimatedTotal = budget
        do {
            try await SupabaseClient.shared.update(
                "shopping_lists",
                values: ShoppingListPatch(name: cleanName, estimated_total: budget),
                match: ["id": list.id]
            )
            await app.refreshAll()
        } catch {
            list.name = previousName
            list.estimatedTotal = previousBudget
            actionError = error.localizedDescription
        }
    }

    // MARK: - Eliminar lista

    private func deleteList() async {
        do {
            // shopping_items.list_id tiene ON DELETE CASCADE → basta con borrar la lista.
            try await SupabaseClient.shared.deleteRow("shopping_lists", match: ["id": list.id])
            await app.refreshAll()
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Guardar como plantilla

    private func saveAsTemplate() {
        guard !items.isEmpty else { return }
        struct TemplateItem: Encodable {
            let name: String
            let quantity: Double
            let unit: String?
            let estimated_price: Double?
            let category_id: String?
        }
        struct Insert: Encodable {
            let household_id: String
            let name: String
            let items: [TemplateItem]
        }
        let payload = Insert(
            household_id: list.householdId,
            name: list.name,
            items: items.map {
                TemplateItem(name: $0.name, quantity: $0.quantity, unit: $0.unit, estimated_price: $0.estimatedPrice, category_id: $0.categoryId)
            }
        )
        Task {
            do {
                let _: [EmptyDecodable] = try await SupabaseClient.shared.insert("shopping_templates", values: payload)
                showTemplateSaved = true
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func applyLocal(_ id: String, _ mutate: (inout ShoppingItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(Motion.ui) { mutate(&items[index]) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })
    }

    private var deleteItemBinding: Binding<Bool> {
        Binding(get: { deleteItemTarget != nil }, set: { if !$0 { deleteItemTarget = nil } })
    }
}

// Patch reutilizable para actualizar nombre/presupuesto de una lista.
private struct ShoppingListPatch: Encodable {
    let name: String
    let estimated_total: Double?
}

// MARK: - Fila de ítem

private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let category: Category?
    let currency: String
    let tint: Color
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var quantityText: String {
        let qty = item.quantity
        let qtyString = qty.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(qty))
            : String(format: "%.1f", qty)
        var parts: [String] = []
        if qty != 1 { parts.append(qtyString) }
        if let unit = item.unit, !unit.isEmpty { parts.append(unit) }
        return parts.joined(separator: " ")
    }

    /// Precio a mostrar: real si ya se compró, si no el estimado (× cantidad).
    private var priceText: String? {
        if item.isChecked {
            guard let price = item.actualPrice, price > 0 else { return nil }
            return CurrencyFormatter.string(price * item.quantity, currency: currency)
        }
        guard let price = item.estimatedPrice, price > 0 else { return nil }
        return CurrencyFormatter.string(price * item.quantity, currency: currency)
    }

    private var categoryColor: Color {
        Color(hexString: category?.color ?? "") ?? Palette.inkTertiary
    }

    var body: some View {
        Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                // Checkbox: sólo togglea comprado (área de toque propia).
                Button(action: onToggle) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(item.isChecked ? tint : Palette.inkTertiary)
                        .animation(Motion.ui, value: item.isChecked)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pressable(scale: 0.9)

                // Cuerpo: toca para editar el ítem.
                Button(action: onEdit) {
                    HStack(spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(Typo.body)
                                .foregroundStyle(item.isChecked ? Palette.inkTertiary : Palette.ink)
                                .strikethrough(item.isChecked, color: Palette.inkTertiary)
                                .lineLimit(1)
                            HStack(spacing: Space.s) {
                                if !quantityText.isEmpty {
                                    Text(quantityText)
                                        .font(Typo.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                                if let category {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(categoryColor)
                                            .frame(width: 6, height: 6)
                                        Text(category.name)
                                            .font(Typo.caption)
                                            .foregroundStyle(Palette.inkTertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: Space.s)

                        if let priceText {
                            Text(priceText)
                                .font(Typo.amount)
                                .monospacedDigit()
                                .foregroundStyle(item.isChecked ? Palette.inkTertiary : Palette.ink)
                        } else if !item.isChecked {
                            Text("+ Precio")
                                .font(Typo.caption)
                                .foregroundStyle(tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Editar ítem", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar ítem", systemImage: "trash")
            }
        }
    }
}

// MARK: - Barra de progreso

private struct ShoppingProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceElevated)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(Motion.value, value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Sheet: precio real al marcar comprado

private struct ShoppingPriceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ShoppingItem
    let currency: String
    let tint: Color
    let onConfirm: (Double?) async -> Void

    @State private var digits = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: Space.l) {
                    VStack(spacing: Space.xs) {
                        Text("PRECIO REAL")
                            .font(Typo.overline)
                            .tracking(1.2)
                            .foregroundStyle(tint)
                        Text(formatted)
                            .font(Typo.amountHero(48))
                            .monospacedDigit()
                            .foregroundStyle(value > 0 ? Palette.ink : Palette.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .contentTransition(.numericText(value: value))
                            .animation(Motion.value, value: value)
                        Text("¿Cuánto costó “\(item.name)”?")
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Space.m)

                    Spacer(minLength: 0)

                    keypad

                    PrimaryButton(
                        title: isSaving ? "Guardando…" : "Confirmar compra",
                        icon: isSaving ? nil : "checkmark",
                        tint: tint,
                        fg: Palette.bg
                    ) {
                        confirm()
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, Space.l)
                    .padding(.bottom, Space.s)
                }
            }
            .navigationTitle("Marcar comprado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .onAppear {
            if let est = item.estimatedPrice, est > 0 {
                digits = String(Int(est.rounded()))
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        ComprasKeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, Space.l)
    }

    private let rows: [[ComprasKeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    private func tap(_ key: ComprasKeypadKey) {
        switch key {
        case .digit(let d):
            guard digits.count < 12 else { return }
            if digits.isEmpty && d == "0" { return }
            digits.append(d)
        case .delete:
            if !digits.isEmpty { digits.removeLast() }
        case .clear:
            digits = ""
        }
    }

    private var value: Double { Double(digits) ?? 0 }
    private var formatted: String { CurrencyFormatter.string(value, currency: currency) }

    private func confirm() {
        isSaving = true
        Task {
            await onConfirm(value > 0 ? value : nil)
            dismiss()
        }
    }
}

// MARK: - Sheet: crear / editar ítem (nombre, cantidad, unidad, precio, categoría)

private struct ShoppingItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let confirmLabel: String
    let existing: ShoppingItem?
    let categories: [Category]
    let currency: String
    let tint: Color
    /// (nombre, cantidad, unidad, precio estimado por unidad, categoryId)
    let onSave: (_ name: String, _ quantity: Double, _ unit: String?, _ estimated: Double?, _ categoryId: String?) async -> Void

    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unit = ""
    @State private var priceDigits = ""
    @State private var categoryId: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.l) {
                        // Nombre
                        Card(padding: Space.m) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text("PRODUCTO")
                                    .font(Typo.overline)
                                    .foregroundStyle(Palette.inkTertiary)
                                TextField(
                                    "",
                                    text: $name,
                                    prompt: Text("Ej. Leche entera").foregroundColor(Palette.inkTertiary)
                                )
                                .font(Typo.body)
                                .foregroundStyle(Palette.ink)
                                .submitLabel(.done)
                            }
                        }

                        // Cantidad + unidad
                        HStack(spacing: Space.m) {
                            Card(padding: Space.m) {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("CANTIDAD")
                                        .font(Typo.overline)
                                        .foregroundStyle(Palette.inkTertiary)
                                    TextField("1", text: $quantityText)
                                        .font(Typo.body)
                                        .foregroundStyle(Palette.ink)
                                        .keyboardType(.decimalPad)
                                        .monospacedDigit()
                                }
                            }
                            Card(padding: Space.m) {
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text("UNIDAD")
                                        .font(Typo.overline)
                                        .foregroundStyle(Palette.inkTertiary)
                                    TextField(
                                        "",
                                        text: $unit,
                                        prompt: Text("kg, lb…").foregroundColor(Palette.inkTertiary)
                                    )
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.ink)
                                    .autocorrectionDisabled()
                                }
                            }
                        }

                        // Precio estimado
                        Card(padding: Space.m) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text("PRECIO ESTIMADO (POR UNIDAD)")
                                    .font(Typo.overline)
                                    .foregroundStyle(Palette.inkTertiary)
                                HStack {
                                    Text(estimatedFormatted)
                                        .font(Typo.amountMedium)
                                        .monospacedDigit()
                                        .foregroundStyle(estimatedValue > 0 ? Palette.ink : Palette.inkTertiary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                        }

                        // Categoría del ítem
                        if !categories.isEmpty {
                            VStack(alignment: .leading, spacing: Space.s) {
                                Text("CATEGORÍA")
                                    .font(Typo.overline)
                                    .foregroundStyle(Palette.inkTertiary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Space.s) {
                                        ForEach(categories) { cat in
                                            ShoppingCategoryChip(
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        keypad
                    }
                    .padding(Space.l)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: isSaving ? "Guardando…" : confirmLabel,
                    icon: isSaving ? nil : "checkmark",
                    tint: canSave ? tint : Palette.surfaceElevated,
                    fg: canSave ? Palette.bg : Palette.inkTertiary
                ) {
                    save()
                }
                .disabled(!canSave || isSaving)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.s)
                .background(Palette.bg)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let existing else { return }
        name = existing.name
        let qty = existing.quantity
        quantityText = qty.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(qty)) : String(format: "%g", qty)
        unit = existing.unit ?? ""
        if let price = existing.estimatedPrice, price > 0 {
            priceDigits = String(Int(price.rounded()))
        }
        categoryId = existing.categoryId
    }

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        ComprasKeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
    }

    private let rows: [[ComprasKeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.clear, .digit("0"), .delete],
    ]

    private func tap(_ key: ComprasKeypadKey) {
        switch key {
        case .digit(let d):
            guard priceDigits.count < 12 else { return }
            if priceDigits.isEmpty && d == "0" { return }
            priceDigits.append(d)
        case .delete:
            if !priceDigits.isEmpty { priceDigits.removeLast() }
        case .clear:
            priceDigits = ""
        }
    }

    private var estimatedValue: Double { Double(priceDigits) ?? 0 }
    private var estimatedFormatted: String { CurrencyFormatter.string(estimatedValue, currency: currency) }

    private var quantityValue: Double {
        let normalized = quantityText.replacingOccurrences(of: ",", with: ".")
        let parsed = Double(normalized.filter { "0123456789.".contains($0) }) ?? 1
        return parsed > 0 ? parsed : 1
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        isSaving = true
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await onSave(
                cleanName,
                quantityValue,
                cleanUnit.isEmpty ? nil : cleanUnit,
                estimatedValue > 0 ? estimatedValue : nil,
                categoryId
            )
            dismiss()
        }
    }
}

// MARK: - Sheet: editar lista (nombre + presupuesto)

private struct ShoppingListEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let name: String
    let budget: Double?
    let currency: String
    let tint: Color
    let onSave: (_ name: String, _ budget: Double?) async -> Void

    @State private var nameText: String
    @State private var budgetDigits: String
    @State private var isSaving = false

    init(name: String, budget: Double?, currency: String, tint: Color, onSave: @escaping (_ name: String, _ budget: Double?) async -> Void) {
        self.name = name
        self.budget = budget
        self.currency = currency
        self.tint = tint
        self.onSave = onSave
        _nameText = State(initialValue: name)
        _budgetDigits = State(initialValue: (budget.map { $0 > 0 ? String(Int($0.rounded())) : "" }) ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Space.xl) {
                        VStack(spacing: Space.xs) {
                            Text("PRESUPUESTO ESTIMADO")
                                .font(Typo.overline)
                                .tracking(1.2)
                                .foregroundStyle(tint)
                            Text(formattedBudget)
                                .font(Typo.amountHero(48))
                                .monospacedDigit()
                                .foregroundStyle(budgetValue > 0 ? Palette.ink : Palette.inkTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .contentTransition(.numericText(value: budgetValue))
                                .animation(Motion.value, value: budgetValue)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, Space.m)

                        Card(padding: Space.m) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text("NOMBRE DE LA LISTA")
                                    .font(Typo.overline)
                                    .foregroundStyle(Palette.inkTertiary)
                                TextField(
                                    "",
                                    text: $nameText,
                                    prompt: Text("Ej. Mercado semanal").foregroundColor(Palette.inkTertiary)
                                )
                                .font(Typo.body)
                                .foregroundStyle(Palette.ink)
                                .submitLabel(.done)
                            }
                        }

                        keypad
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.bottom, Space.l)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: isSaving ? "Guardando…" : "Guardar cambios",
                    icon: isSaving ? nil : "checkmark",
                    tint: canSave ? tint : Palette.surfaceElevated,
                    fg: canSave ? Palette.bg : Palette.inkTertiary
                ) {
                    save()
                }
                .disabled(!canSave || isSaving)
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
                .padding(.bottom, Space.s)
                .background(Palette.bg)
            }
            .navigationTitle("Editar lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .tint(Palette.accent)
        .presentationDragIndicator(.visible)
    }

    private var keypad: some View {
        VStack(spacing: Space.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in
                        ComprasKeypadButton(key: key) { tap(key) }
                    }
                }
            }
        }
        .padding(.horizontal, Space.l)
    }

    private let rows: [[ComprasKeypadKey]] = [
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

    private var budgetValue: Double { Double(budgetDigits) ?? 0 }
    private var formattedBudget: String { CurrencyFormatter.string(budgetValue, currency: currency) }

    private var canSave: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        isSaving = true
        let clean = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await onSave(clean, budgetValue > 0 ? budgetValue : nil)
            dismiss()
        }
    }
}

// MARK: - Chip de categoría (para ítems)

private struct ShoppingCategoryChip: View {
    let category: Category
    let isSelected: Bool
    var action: () -> Void

    private var color: Color {
        Color(hexString: category.color) ?? Palette.sky
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let icon = CategoryIconAsset.image(forSlug: category.icon) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                } else {
                    Image(systemName: IconMapping.sfSymbol(for: category.icon))
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(category.name)
                    .font(Typo.callout)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? color : Palette.inkSecondary)
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(
                (isSelected ? color.opacity(0.16) : Palette.surfaceElevated),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? color : Palette.stroke.opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .pressable()
    }
}

// MARK: - Cargando

private struct ShoppingDetailLoading: View {
    var body: some View {
        HStack(spacing: Space.s) {
            ProgressView()
                .tint(Palette.inkSecondary)
            Text("Cargando ítems…")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Estado vacío

private struct ShoppingDetailEmptyState: View {
    let failed: Bool

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: failed ? "exclamationmark.triangle.fill" : "cart.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(failed ? Palette.amber : Palette.sky)
            Text(failed ? "No se pudo cargar" : "Lista vacía")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text(failed
                 ? "Revisa tu conexión e intenta de nuevo."
                 : "Aún no hay ítems. Escribe abajo para agregar lo que necesiten comprar.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}
