import SwiftUI

// Detalle de una lista de compra: ítems chequeables con cantidad, unidad y
// precio, y el total abajo. Carga los ítems bajo demanda desde el Repository.

struct ShoppingListDetailView: View {
    @Environment(AppState.self) private var app

    let list: ShoppingList

    @State private var items: [ShoppingItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var tint: Color { ShoppingStatusStyle.tint(for: list.status) }

    /// Total con base en el mejor precio disponible por ítem (real si existe,
    /// si no el estimado) multiplicado por la cantidad.
    private var total: Double {
        items.reduce(0) { sum, item in
            let unitPrice = item.actualPrice ?? item.estimatedPrice ?? 0
            return sum + unitPrice * item.quantity
        }
    }

    private var checkedCount: Int {
        items.filter { $0.isChecked }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header

                if isLoading {
                    ShoppingDetailLoading()
                        .padding(.top, Space.xl)
                } else if items.isEmpty {
                    ShoppingDetailEmptyState(failed: loadFailed)
                        .padding(.top, Space.xl)
                } else {
                    VStack(spacing: Space.s) {
                        ForEach(items) { item in
                            ShoppingItemRow(
                                item: item,
                                currency: app.currency,
                                tint: tint,
                                onToggle: { toggle(item) }
                            )
                        }
                    }

                    ShoppingTotalCard(total: total, currency: app.currency, tint: tint)
                        .padding(.top, Space.s)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.l)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                ShoppingStatusBadge(status: list.status)
                if let store = list.store, !store.isEmpty {
                    Label(store, systemImage: "storefront")
                        .labelStyle(.titleAndIcon)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
            }
            if !items.isEmpty {
                Text("\(checkedCount) de \(items.count) marcados")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkTertiary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: Carga

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            items = try await Repository().fetchShoppingItems(list: list.id)
        } catch {
            loadFailed = true
            items = []
        }
        isLoading = false
    }

    // MARK: Toggle local (optimista)

    private func toggle(_ item: ShoppingItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(Motion.ui) {
            items[index].isChecked.toggle()
        }
    }
}

// MARK: - Fila de ítem

private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let currency: String
    let tint: Color
    let onToggle: () -> Void

    private var quantityText: String {
        let qty = item.quantity
        let qtyString = qty.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(qty))
            : String(format: "%.1f", qty)
        if let unit = item.unit, !unit.isEmpty {
            return "\(qtyString) \(unit)"
        }
        return qtyString
    }

    private var priceText: String? {
        guard let price = item.actualPrice ?? item.estimatedPrice, price > 0 else { return nil }
        return CurrencyFormatter.string(price * item.quantity, currency: currency)
    }

    var body: some View {
        Button(action: onToggle) {
            Card(padding: Space.m) {
                HStack(spacing: Space.m) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(item.isChecked ? tint : Palette.inkTertiary)
                        .animation(Motion.ui, value: item.isChecked)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(Typo.body)
                            .foregroundStyle(item.isChecked ? Palette.inkTertiary : Palette.ink)
                            .strikethrough(item.isChecked, color: Palette.inkTertiary)
                            .lineLimit(1)
                        Text(quantityText)
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkSecondary)
                    }

                    Spacer(minLength: Space.s)

                    if let priceText {
                        Text(priceText)
                            .font(Typo.amount)
                            .monospacedDigit()
                            .foregroundStyle(item.isChecked ? Palette.inkTertiary : Palette.ink)
                    }
                }
            }
        }
        .pressable()
    }
}

// MARK: - Tarjeta de total

private struct ShoppingTotalCard: View {
    let total: Double
    let currency: String
    let tint: Color

    var body: some View {
        Card {
            HStack {
                Text("Total")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                Text(CurrencyFormatter.string(total, currency: currency))
                    .font(Typo.amountMedium)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
        }
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
            Image(systemName: failed ? "exclamationmark.triangle.fill" : "list.bullet")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(failed ? Palette.amber : Palette.sky)
            Text(failed ? "No se pudo cargar" : "Lista vacía")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text(failed
                 ? "Revisa tu conexión e intenta de nuevo."
                 : "Aún no hay ítems en esta lista. Agrega lo que necesiten comprar.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}
