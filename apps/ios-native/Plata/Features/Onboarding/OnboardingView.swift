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
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingBlobField()
                    .frame(height: 300)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)

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

/// Composición de formas coloridas suavemente difuminadas. Cada blob usa un
/// acento de la paleta y respira con una animación lenta y continua para dar
/// vida sin distraer.
private struct OnboardingBlobField: View {
    @State private var breathe = false

    var body: some View {
        ZStack {
            OnboardingBlob(color: Palette.green, size: 190)
                .offset(x: -70, y: -40)
                .offset(y: breathe ? -8 : 8)

            OnboardingBlob(color: Palette.pink, size: 150)
                .offset(x: 90, y: -60)
                .offset(y: breathe ? 10 : -6)

            OnboardingBlob(color: Palette.sky, size: 170)
                .offset(x: 70, y: 70)
                .offset(y: breathe ? -6 : 10)

            OnboardingBlob(color: Palette.purple, size: 130)
                .offset(x: -80, y: 80)
                .offset(y: breathe ? 8 : -8)

            OnboardingBlob(color: Palette.amber, size: 110)
                .offset(x: 0, y: 0)
                .offset(y: breathe ? -10 : 6)

            // Anillo central de marca, nítido sobre el bokeh.
            Circle()
                .strokeBorder(Palette.ink.opacity(0.9), lineWidth: 2)
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                )
                .shadow(color: Palette.bg.opacity(0.6), radius: 12, y: 4)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

private struct OnboardingBlob: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color.opacity(0.55))
            .frame(width: size, height: size)
            .blur(radius: 42)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
