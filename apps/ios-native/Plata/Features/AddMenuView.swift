import SwiftUI

// Menú del botón "+" central de la tab bar. Paridad con FloatingMenu.tsx del
// original RN: presenta las 7 acciones de creación (transacción, presupuesto,
// lista de compras, meta de ahorro, deuda, cuenta y evento/recurrente), cada
// una como fila con un CategoryIcon (ícono SF en círculo de color) + label.
// Al elegir una opción se cierra este sheet y MainTabView presenta el add
// correspondiente. Estética Plata: dark, elegante, color con propósito.

// Destino de creación seleccionable desde el menú "+". Identifiable para
// manejar la presentación con `.sheet(item:)` desde MainTabView.
enum AddDestination: String, Identifiable, CaseIterable {
    case transaction
    case budget
    case shoppingList
    case goal
    case debt
    case account
    case recurring

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transaction: "Transacción"
        case .budget: "Presupuesto"
        case .shoppingList: "Lista de compras"
        case .goal: "Meta de ahorro"
        case .debt: "Deuda"
        case .account: "Cuenta"
        case .recurring: "Evento recurrente"
        }
    }

    var subtitle: String {
        switch self {
        case .transaction: "Registra un ingreso o gasto"
        case .budget: "Fija un límite por categoría"
        case .shoppingList: "Planea una compra"
        case .goal: "Ahorra hacia un objetivo"
        case .debt: "Registra lo que deben o debes"
        case .account: "Añade una cuenta o billetera"
        case .recurring: "Suscripción o pago periódico"
        }
    }

    var icon: String {
        switch self {
        case .transaction: "arrow.up.arrow.down"
        case .budget: "chart.pie.fill"
        case .shoppingList: "cart.fill"
        case .goal: "target"
        case .debt: "arrow.left.arrow.right"
        case .account: "wallet.pass.fill"
        case .recurring: "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .transaction: Palette.accent
        case .budget: Palette.amber
        case .shoppingList: Palette.sky
        case .goal: Palette.green
        case .debt: Palette.pink
        case .account: Palette.indigo
        case .recurring: Palette.purple
        }
    }
}

struct AddMenuView: View {
    @Environment(\.dismiss) private var dismiss

    // Se invoca con el destino elegido; MainTabView cierra este sheet y presenta
    // el add correspondiente.
    var onSelect: (AddDestination) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s) {
                        ForEach(Array(AddDestination.allCases.enumerated()), id: \.element) { index, destination in
                            Button {
                                onSelect(destination)
                            } label: {
                                AddMenuRow(destination: destination)
                            }
                            .pressable()
                            .transition(.opacity)
                            .animation(Motion.ui.delay(Double(index) * 0.02), value: destination)
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.m)
                }
            }
            .navigationTitle("Crear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.bg)
    }
}

// MARK: - Fila del menú

private struct AddMenuRow: View {
    let destination: AddDestination

    var body: some View {
        HStack(spacing: Space.m) {
            CategoryIcon(systemName: destination.icon, color: destination.tint, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.label)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text(destination.subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}
