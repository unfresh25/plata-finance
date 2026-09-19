import SwiftUI

// Bienvenida: carrusel de features deslizable (Registrar por voz · Asistente IA ·
// En pareja) con dots de paginación y un CTA fijo abajo. Fondo limpio, sin moneda,
// violeta solo como acento sutil. Al terminar avanza al cuestionario y luego a la
// fase de autenticación (RootView anima el cambio de fase).

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    @State private var page = 0
    @State private var showSurvey = false

    private struct Feature: Identifiable {
        let id = UUID()
        let image: String
        let title: String
        let subtitle: String
    }

    private let features: [Feature] = [
        .init(image: "Onb_voz",
              title: "Registra por voz",
              subtitle: "Di “gasté 20 mil en el mercado” y listo. La app entiende y lo anota por ti."),
        .init(image: "Onb_asistente",
              title: "Tu asistente de plata",
              subtitle: "Pregúntale en qué gastan más, cómo van con las metas o pídele un consejo."),
        .init(image: "Onb_pareja",
              title: "En pareja, sin peleas",
              subtitle: "Ahorren, gasten y planeen juntos, con todo claro para los dos."),
    ]

    var body: some View {
        ZStack {
            welcome
            if showSurvey {
                OnboardingQuestionsView(onFinish: finish)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            // Carrusel deslizable de features.
            TabView(selection: $page) {
                ForEach(Array(features.enumerated()), id: \.element.id) { i, f in
                    featureSlide(f).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(Motion.ui, value: page)

            // Dots de paginación.
            HStack(spacing: 8) {
                ForEach(features.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Palette.accent : Palette.stroke)
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(Motion.ui, value: page)
                }
            }
            .padding(.bottom, Space.xl)

            // CTA fijo abajo.
            VStack(spacing: Space.m) {
                PrimaryButton(title: page == features.count - 1 ? "Empezar" : "Siguiente",
                              icon: page == features.count - 1 ? "arrow.right" : nil) {
                    advance()
                }
                Button(action: start) {
                    Text(page == features.count - 1 ? "Gratis para ti y tu pareja" : "Saltar")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xxl)
        }
        .background(Palette.bg.ignoresSafeArea())
    }

    private func featureSlide(_ f: Feature) -> some View {
        VStack(spacing: Space.l) {
            Spacer()
            // Ilustración de marca del feature.
            Image(f.image)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(.bottom, Space.l)

            Text(f.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)

            Text(f.subtitle)
                .font(Typo.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.xl)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Space.l)
    }

    // MARK: - Flujo

    /// "Siguiente"/"Empezar": avanza el carrusel o, en el último, entra al cuestionario.
    private func advance() {
        if page < features.count - 1 {
            withAnimation(Motion.ui) { page += 1 }
        } else {
            start()
        }
    }

    /// Entra al cuestionario (también desde "Saltar").
    private func start() {
        withAnimation(.easeInOut(duration: 0.4)) { showSurvey = true }
    }

    /// Fin del cuestionario → avanza a la fase de autenticación.
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
