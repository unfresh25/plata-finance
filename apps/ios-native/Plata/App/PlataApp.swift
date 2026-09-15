import SwiftUI

@main
struct PlataApp: App {
    @State private var app: AppState = ProcessInfo.processInfo.arguments.contains("-uiPreview")
        ? .previewMocked
        : AppState()

    private var isPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiPreview")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .task { if !isPreview { await app.bootstrap() } }
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
                    ProgressView().tint(Palette.accent)
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
