import SwiftUI

// Shell principal de la app: barra de tabs custom oscura con un botón central "+"
// destacado que presenta AddTransactionView como sheet. Cuatro destinos de
// navegación (Inicio, Movimientos, Cuentas, Ajustes) + la acción central.
//
// Las Views de destino (DashboardView, TransactionsView, AccountsView,
// SettingsView, AddTransactionView) viven en sus propias features del mismo
// módulo — aquí solo se orquesta la navegación.

struct MainTabView: View {
    @Environment(AppState.self) private var app

    @State private var selection: MainTab = {
        // Permite arrancar en una tab concreta para previsualización (-startTab finanzas).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "finanzas": return .finances
            case "movim": return .transactions
            case "ajustes": return .settings
            default: return .home
            }
        }
        return .home
    }()
    @State private var showingAddMenu = false
    // Destino elegido en el menú "+", promovido tras cerrar el menú para evitar
    // presentar un sheet mientras otro se está descartando.
    @State private var pendingDestination: AddDestination?
    @State private var activeDestination: AddDestination?

    var body: some View {
        // Contenido del tab activo. Cada destino en su propio NavigationStack
        // para conservar su pila al cambiar de pestaña. La barra flotante se
        // inyecta como safeAreaInset(.bottom): así reserva EXACTAMENTE su propia
        // altura y ningún contenido (ni el de pantallas empujadas por push)
        // queda oculto tras ella. Un spacer fijo se quedaba corto.
        Group {
            switch selection {
            case .home:
                NavigationStack { DashboardView() }
            case .transactions:
                NavigationStack { TransactionsView() }
            case .finances:
                NavigationStack { FinancesView() }
            case .settings:
                NavigationStack { SettingsView() }
            }
        }
        .transition(.opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selection: $selection) {
                showingAddMenu = true
            }
        }
        .task {
            // En modo preview (-uiPreview) se conservan los datos mock inyectados.
            if !ProcessInfo.processInfo.arguments.contains("-uiPreview") {
                await app.refreshAll()
            }
        }
        // Menú "+": las 7 acciones de creación. Al elegir una se cierra el menú
        // y, en su onDismiss, se promueve el destino elegido para presentar el
        // add correspondiente (evita presentar mientras otro sheet se descarta).
        .sheet(isPresented: $showingAddMenu, onDismiss: {
            if let pending = pendingDestination {
                pendingDestination = nil
                activeDestination = pending
            }
        }) {
            AddMenuView { destination in
                pendingDestination = destination
                showingAddMenu = false
            }
        }
        .sheet(item: $activeDestination) { destination in
            addView(for: destination)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bg)
        }
    }

    // Presenta el add correspondiente al destino elegido. Cada AddXView ya
    // incorpora su propio NavigationStack, por eso aquí se devuelve directa.
    @ViewBuilder
    private func addView(for destination: AddDestination) -> some View {
        switch destination {
        case .transaction: AddTransactionView()
        case .budget: AddBudgetView()
        case .shoppingList: AddShoppingListView()
        case .goal: AddGoalView()
        case .debt: AddDebtView()
        case .account: AddAccountView()
        case .recurring: AddRecurringView()
        }
    }
}

// MARK: - Modelo de pestañas

private enum MainTab: Hashable, CaseIterable {
    case home, transactions, finances, settings

    var title: String {
        switch self {
        case .home: "Inicio"
        case .transactions: "Movim."
        case .finances: "Finanzas"
        case .settings: "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .transactions: "list.bullet"
        case .finances: "chart.pie"
        case .settings: "gearshape"
        }
    }

    var iconSelected: String {
        switch self {
        case .home: "house.fill"
        case .transactions: "list.bullet"
        case .finances: "chart.pie.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - Barra custom

private struct MainTabBar: View {
    @Binding var selection: MainTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            MainTabBarButton(tab: .home, selection: $selection)
            MainTabBarButton(tab: .transactions, selection: $selection)

            MainTabAddButton(action: onAdd)
                .padding(.horizontal, Space.s)

            MainTabBarButton(tab: .finances, selection: $selection)
            MainTabBarButton(tab: .settings, selection: $selection)
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, Space.s)
        .liquidGlassCapsule()
        .overlay(
            Capsule(style: .continuous).strokeBorder(Palette.stroke.opacity(0.5), lineWidth: 1)
        )
        // Sombra sutil multicapa: separa la barra del contenido sin pesar.
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.s)
        // Aire por encima de la barra: como se inyecta vía safeAreaInset, este
        // padding superior se suma al espacio reservado, dando holgura entre el
        // último elemento del contenido y la barra flotante (antes quedaba pegado).
        .padding(.top, Space.m)
    }
}

private struct MainTabBarButton: View {
    let tab: MainTab
    @Binding var selection: MainTab

    private var isSelected: Bool { selection == tab }

    var body: some View {
        Button {
            withAnimation(Motion.ui) { selection = tab }
        } label: {
            VStack(spacing: Space.xs) {
                Image(systemName: isSelected ? tab.iconSelected : tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolVariant(.none)
                    .frame(height: 22)
                Text(tab.title)
                    .font(Typo.overline)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Palette.accent : Palette.inkTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .pressable(scale: 0.92)
    }
}

private struct MainTabAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 52, height: 52)
                .background(Palette.accent, in: Circle())
                // Sombra neutra sutil (no glow de color): da elevación sin ruido.
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .pressable(scale: 0.94)
        .accessibilityLabel("Añadir movimiento")
    }
}
