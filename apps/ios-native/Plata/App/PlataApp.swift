import SwiftUI

@main
struct PlataApp: App {
    @State private var app: AppState = ProcessInfo.processInfo.arguments.contains("-uiPreview")
        ? .previewMocked
        : AppState()
    @State private var theme = ThemeManager()

    private var isPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiPreview")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(Palette.accent)
                .task {
                    if !isPreview {
                        await app.bootstrap()
                        await NotificationService.requestAuthorization()
                    }
                }
        }
    }
}

/// Enruta la app según la fase de autenticación.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            // Atajo de previsualización: -screen calendar|reports|recurring|categories
            if let screen = previewScreen {
                NavigationStack { screen }
            } else {
                switch app.phase {
                case .loading:
                    LaunchView()
                case .onboarding:
                    OnboardingView()
                case .unauthenticated:
                    AuthView()
                case .noHousehold:
                    HouseholdSetupView()
                case .ready:
                    MainTabView()
                }
            }
        }
        .animation(Motion.ui, value: app.phase)
    }

    private var previewScreen: AnyView? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "calendar": return AnyView(CalendarView())
        case "reports": return AnyView(ReportsView())
        case "recurring": return AnyView(RecurringView())
        case "categories": return AnyView(CategoriesView())
        default: return nil
        }
    }
}

/// Pantalla de carga (fase .loading): el logotipo de marca centrado sobre el
/// fondo oscuro de la app, sin spinner. Se dibuja el wordmark "plata." de forma
/// nativa (mono + punto azul) para que quede perfectamente centrado y nítido a
/// cualquier tamaño. El fondo coincide con el del launch screen del sistema
/// (#141119), así el arranque es continuo y sin flash. Fija a apariencia oscura.
struct LaunchView: View {
    private let brandBackground = Color(red: 0x14 / 255, green: 0x11 / 255, blue: 0x19 / 255)
    private let brandDot = Color(red: 0x1E / 255, green: 0x3F / 255, blue: 0xF5 / 255)

    var body: some View {
        ZStack {
            brandBackground.ignoresSafeArea()
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("plata")
                    .font(.system(size: 44, weight: .medium, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(.white)
                Text(".")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(brandDot)
            }
        }
    }
}
