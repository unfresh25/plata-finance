import SwiftUI

// Listas de compra de la pareja. Cada lista es una tarjeta tappable que abre
// su detalle con los ítems chequeables.

struct ShoppingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    if app.shoppingLists.isEmpty {
                        ShoppingEmptyState()
                            .padding(.top, Space.xxxl)
                    } else {
                        SectionLabel(text: "Listas")
                            .padding(.bottom, Space.xs)
                        ForEach(app.shoppingLists) { list in
                            NavigationLink {
                                ShoppingListDetailView(list: list)
                            } label: {
                                ShoppingListCard(list: list, currency: app.currency)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.l)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Compras")
        }
    }
}

// MARK: - Tarjeta de lista

private struct ShoppingListCard: View {
    let list: ShoppingList
    let currency: String

    var body: some View {
        Card {
            HStack(spacing: Space.m) {
                CategoryIcon(
                    systemName: "cart.fill",
                    color: ShoppingStatusStyle.tint(for: list.status),
                    size: 44
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    HStack(spacing: Space.s) {
                        ShoppingStatusBadge(status: list.status)
                        if let store = list.store, !store.isEmpty {
                            Label(store, systemImage: "storefront")
                                .labelStyle(.titleAndIcon)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: Space.s)

                VStack(alignment: .trailing, spacing: 2) {
                    if let estimated = list.estimatedTotal, estimated > 0 {
                        Text(CurrencyFormatter.string(estimated, currency: currency))
                            .font(Typo.amount)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                        Text("estimado")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Badge de estado

struct ShoppingStatusBadge: View {
    let status: ListStatus

    var body: some View {
        let tint = ShoppingStatusStyle.tint(for: status)
        Text(ShoppingStatusStyle.label(for: status))
            .font(Typo.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
    }
}

// MARK: - Estilo compartido de estado

enum ShoppingStatusStyle {
    static func tint(for status: ListStatus) -> Color {
        switch status {
        case .open: return Palette.sky
        case .shopping: return Palette.amber
        case .completed: return Palette.green
        }
    }

    static func label(for status: ListStatus) -> String {
        switch status {
        case .open: return "Por comprar"
        case .shopping: return "Comprando"
        case .completed: return "Completada"
        }
    }
}

// MARK: - Estado vacío

private struct ShoppingEmptyState: View {
    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "cart")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Palette.sky)
            Text("Sin listas")
                .font(Typo.title)
                .foregroundStyle(Palette.ink)
            Text("Crea una lista de compra para organizar el mercado en pareja y llevar la cuenta de lo que van necesitando.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
    }
}
