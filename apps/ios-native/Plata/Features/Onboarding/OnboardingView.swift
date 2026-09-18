import SwiftUI

// Pantalla de bienvenida. Formas de color (blobs) suaves arriba, título grande y
// un único CTA. Al pulsar "Empezar" marcamos el flag y avanzamos a la fase de
// autenticación; RootView anima el cambio de fase por nosotros.

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    @State private var appeared = false
    @State private var showIntro = false
    @State private var showSurvey = false

    var body: some View {
        ZStack {
            welcome

            // Intro cinemática (encima), tras tocar "Empezar".
            if showIntro {
                IntroSequence(onFinish: introDidFinish)
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Cuestionario, después de la intro y antes de autenticarse.
            if showSurvey {
                OnboardingQuestionsView(onFinish: finish)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    }

    private var welcome: some View {
        ZStack {
            // Degradado estilo Fuse: violeta abajo que sube y muere en el fondo
            // por arriba. Intensidad contenida para un look elegante, no brillante.
            FuseGradient()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: Space.xl)

                // Contenido anclado abajo, sobre el color → texto en blanco.
                VStack(alignment: .leading, spacing: Space.l) {
                    // Moneda de marca (tortuga) como logo.
                    Image("CoinLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("El control de tu plata,\nen pareja")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Text("Ahorren, gasten y planeen juntos,\ncon claridad y sin peleas.")
                        .font(Typo.body)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)

                    // Botones pill: primario blanco sólido + secundario translúcido.
                    VStack(spacing: Space.m) {
                        Button(action: start) {
                            Text("Empezar")
                                .font(Typo.headline)
                                .foregroundStyle(Palette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.l)
                                .background(.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .pressable()

                        Text("Gratis para ti y tu pareja")
                            .font(Typo.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, Space.s)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xxl)
            }
        }
        .onAppear {
            withAnimation(Motion.ui.delay(0.05)) { appeared = true }
        }
    }

    /// "Empezar" → arranca la intro cinemática (una sola vez).
    private func start() {
        withAnimation(.easeInOut(duration: 0.4)) { showIntro = true }
    }

    /// Fin de la intro (o "Saltar" de la intro) → muestra el cuestionario.
    private func introDidFinish() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showSurvey = true
            showIntro = false
        }
    }

    /// Fin del cuestionario (o "Saltar") → avanza a la fase de autenticación.
    private func finish() {
        OnboardingFlag.hasSeen = true
        withAnimation(Motion.ui) { app.phase = .unauthenticated }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
