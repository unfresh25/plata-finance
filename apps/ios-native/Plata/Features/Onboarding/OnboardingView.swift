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
              title: "Juntos, en la misma página",
              subtitle: "Ahorren, gasten y planeen en pareja, con todo claro para los dos."),
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
                        .fill(i == page ? Palette.accent : Color(white: 0.85))
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(Motion.ui, value: page)
                }
            }
            .padding(.bottom, Space.xl)

            // CTA fijo abajo.
            VStack(spacing: Space.m) {
                Button(action: advance) {
                    Text(page == features.count - 1 ? "Empezar" : "Siguiente")
                        .font(Typo.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.l)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .pressable()

                Button(action: start) {
                    Text(page == features.count - 1 ? "Gratis para ti y tu pareja" : "Saltar")
                        .font(Typo.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xxl)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func featureSlide(_ f: Feature) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Ilustración grande protagonista: rebasa el ancho de la pantalla
            // (~1.12x) para que el personaje domine y los stickers respiren.
            GeometryReader { geo in
                Image(f.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 1.12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 420)
            Spacer(minLength: 0)

            VStack(spacing: Space.m) {
                Text(f.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(white: 0.08))
                    .multilineTextAlignment(.center)

                Text(f.subtitle)
                    .font(Typo.body)
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.xl)
            }
            .padding(.bottom, Space.xl)
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
