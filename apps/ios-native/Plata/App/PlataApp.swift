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
        .animation(Motion.ui, value: app.phase)
    }
}
