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

    @State private var selection: MainTab = .home
    @State private var showingAdd = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            // Contenido del tab activo. Cada destino en su propio NavigationStack
            // para conservar su pila al cambiar de pestaña.
            Group {
                switch selection {
                case .home:
                    NavigationStack { DashboardView() }
                case .transactions:
                    NavigationStack { TransactionsView() }
                case .accounts:
                    NavigationStack { AccountsView() }
                case .settings:
                    NavigationStack { SettingsView() }
                }
            }
            .transition(.opacity)
            // Espacio para que el contenido no quede oculto tras la barra flotante.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 64)
            }

            MainTabBar(selection: $selection) {
                showingAdd = true
            }
        }
        .task {
            // En modo preview (-uiPreview) se conservan los datos mock inyectados.
            if !ProcessInfo.processInfo.arguments.contains("-uiPreview") {
                await app.refreshAll()
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { AddTransactionView() }
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bg)
        }
    }
}

// MARK: - Modelo de pestañas

private enum MainTab: Hashable, CaseIterable {
    case home, transactions, accounts, settings

    var title: String {
        switch self {
        case .home: "Inicio"
        case .transactions: "Movim."
        case .accounts: "Cuentas"
        case .settings: "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .transactions: "list.bullet"
        case .accounts: "creditcard"
        case .settings: "gearshape"
        }
    }

    var iconSelected: String {
        switch self {
        case .home: "house.fill"
        case .transactions: "list.bullet"
        case .accounts: "creditcard.fill"
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

            MainTabBarButton(tab: .accounts, selection: $selection)
            MainTabBarButton(tab: .settings, selection: $selection)
        }
        .padding(.horizontal, Space.s)
        .padding(.vertical, Space.s)
        .background(
            Capsule(style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Palette.stroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
        )
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.s)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Palette.bg)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Palette.accent)
                        .shadow(color: Palette.accent.opacity(0.45), radius: 14, x: 0, y: 4)
                )
        }
        .pressable(scale: 0.9)
        .accessibilityLabel("Añadir movimiento")
    }
}
