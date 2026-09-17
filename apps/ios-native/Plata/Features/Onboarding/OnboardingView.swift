import SwiftUI

// Pantalla de bienvenida. Formas de color (blobs) suaves arriba, título grande y
// un único CTA. Al pulsar "Empezar" marcamos el flag y avanzamos a la fase de
// autenticación; RootView anima el cambio de fase por nosotros.

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    @State private var appeared = false
    @State private var wordIndex = 0

    // Palabras que rotan arriba (verbo + su ícono), como el ticker de Fuse.
    private let words: [(text: String, symbol: String)] = [
        ("Ahorrar", "banknote.fill"),
        ("Gastar", "cart.fill"),
        ("Compartir", "person.2.fill"),
        ("Planear", "chart.pie.fill"),
        ("Lograr", "target"),
    ]
    private let ticker = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Degradado estilo Fuse: violeta saturado abajo que sube y muere en
            // el fondo por arriba.
            FuseGradient()

            VStack(alignment: .leading, spacing: 0) {
                // Ticker de palabras arriba, sobre la zona clara del degradado.
                WordTicker(words: words, index: wordIndex)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Space.xxxl)
                    .padding(.horizontal, Space.xl)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: Space.xl)

                // Contenido anclado abajo, sobre el color → texto en blanco.
                VStack(alignment: .leading, spacing: Space.l) {
                    // Ícono de marca en cuadro blanco (como el logo de Fuse).
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 60, height: 60)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .onReceive(ticker) { _ in
            withAnimation(.smooth(duration: 0.5)) { wordIndex += 1 }
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

#Preview {
    OnboardingView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
