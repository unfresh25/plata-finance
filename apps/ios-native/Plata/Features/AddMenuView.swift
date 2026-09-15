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
                // Velo tenue en vez de opaco: deja leer el material del sheet (glass).
                Palette.bg.opacity(0.6).ignoresSafeArea()

                ScrollView {
                    // GlassGroup fusiona (morphing) las filas glass cercanas en iOS 26.
                    GlassGroup(spacing: Space.s) {
                        VStack(spacing: Space.s) {
                            ForEach(AddDestination.allCases) { destination in
                                Button {
                                    onSelect(destination)
                                } label: {
                                    AddMenuRow(destination: destination)
                                }
                                .pressable()
                            }
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
        .glassSheetBackground()
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
                    .tracking(-0.2) // tracking negativo sutil en el título de la fila
                    .foregroundStyle(Palette.ink)
                Text(destination.subtitle)
                    .font(Typo.caption)
                    // Sobre glass el texto secundario necesita más contraste que terciario.
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Una sola capa translúcida (glass) sobre el fondo opaco del sheet: legible.
        .liquidGlass(cornerRadius: Radius.m, interactive: true)
        .overlay(
            // Borde superior luminoso sutil: luz que se posa sobre el material.
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 1)
        )
        // Sombra neutra y sutil, multicapa; nada de glow de acento.
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }
}
