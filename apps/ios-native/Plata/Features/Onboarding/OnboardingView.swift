import SwiftUI

// Pantalla de bienvenida. Formas de color (blobs) suaves arriba, título grande y
// un único CTA. Al pulsar "Empezar" marcamos el flag y avanzamos a la fase de
// autenticación; RootView anima el cambio de fase por nosotros.

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    // Aparición escalonada sutil (Emil: stagger corto, decorativo, no bloquea).
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Mismo fondo aurora violeta que el login (coherencia de marca).
            AuroraBackground(intensity: appeared ? 0.32 : 0.16)
                .animation(.smooth(duration: 0.8), value: appeared)

            VStack(spacing: 0) {
                Spacer(minLength: Space.xl)

                VStack(alignment: .leading, spacing: Space.l) {
                    OnboardingWordmark()
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("El control de tu plata\nen tus manos")
                        .font(Typo.amountLarge)
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(2)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Text("Tu camino hacia el gasto consciente y la tranquilidad empieza aquí.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.xl)

                Spacer(minLength: Space.xl)

                VStack(spacing: Space.m) {
                    PrimaryButton(title: "Empezar", icon: "arrow.right", tint: Palette.accent, fg: Palette.bg) {
                        start()
                    }

                    Text("Gratis para ti y tu pareja")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(Motion.ui.delay(0.05)) { appeared = true }
        }
    }

    private func start() {
        OnboardingFlag.hasSeen = true
        withAnimation(Motion.ui) { app.phase = .unauthenticated }
    }
}

// MARK: - Wordmark

private struct OnboardingWordmark: View {
    var body: some View {
        HStack(spacing: Space.s) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("Plata")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Blob field (formas orgánicas de color con blur sutil)

#Preview {
    OnboardingView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
