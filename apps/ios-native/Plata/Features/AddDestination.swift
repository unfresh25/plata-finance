import SwiftUI

// Destino de creación seleccionable desde el FAB speed-dial (FloatingActionMenu).
// Cada caso define su etiqueta, subtítulo, ícono SF y color. MainTabView presenta
// el AddXView correspondiente al elegido.

enum AddDestination: String, Identifiable, CaseIterable {
    case transaction
    case budget
    case shoppingList
    case goal
    case debt
    case account
    case recurring
    case wish

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
        case .wish: "Deseo"
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
        case .wish: "Guarda algo que sueñas comprar"
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
        case .wish: "sparkles"
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
        case .wish: Palette.accent
        }
    }
}
