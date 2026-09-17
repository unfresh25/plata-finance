import SwiftUI

// Intro cinemática que se reproduce UNA vez al tocar "Empezar" en el onboarding.
// Secuencia:
//   1. Máquina de escribir, frase fragmentada: "a dónde / ¿CANSADO de no saber /
//      se va tu dinero?" (cada trozo en su tamaño y posición).
//   2. Se borra → se escribe "con / PLATA".
//   3. Se borra → ticker de verbos que suben de abajo arriba, uno a la vez
//      (lo controlan / lo reparten / lo ahorran / lo logran).
//   4. Barrido: la moneda de marca aparece grande abajo, sube y se encoge; al
//      terminar, onFinish() lleva al cuestionario de onboarding.
// Botón "Saltar" para quien no quiera esperar.

struct IntroSequence: View {
    var onFinish: () -> Void

    @State private var phase: Phase = .question
    @State private var typed = ""          // texto ya "escrito" de la línea grande
    @State private var showSmallLines = false
    @State private var tickerIndex = 0
    @State private var coinProgress: CGFloat = 0   // 0 = grande abajo, 1 = pequeña arriba
    @State private var coinVisible = false
    @State private var swept = false

    private enum Phase { case question, brand, ticker, sweep }

    // Verbos del ticker.
    private let verbs = ["lo controlan", "lo reparten", "lo ahorran", "lo logran"]

    var body: some View {
        ZStack {
            FuseGradient()

            content

            // Botón saltar.
            VStack {
                HStack {
                    Spacer()
                    Button("Saltar", action: finish)
                        .font(Typo.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(Space.l)
                }
                Spacer()
            }

            // Moneda del barrido (encima de todo durante la fase sweep).
            if coinVisible {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    // De ~todo el ancho abajo (scale 1) a ~64pt arriba.
                    let bigSize = w * 0.9
                    let smallSize: CGFloat = 64
                    let size = bigSize + (smallSize - bigSize) * coinProgress
                    let x = w / 2
                    let yBottom = h * 0.72
                    let yTop = h * 0.16
                    let y = yBottom + (yTop - yBottom) * coinProgress
                    Image("CoinLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .position(x: x, y: y)
                        .shadow(color: .black.opacity(0.3), radius: 20 * (1 - coinProgress), y: 8)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .task { await run() }
    }

    // MARK: - Contenido por fase

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .question:
            VStack(alignment: .leading, spacing: Space.m) {
                Text("a dónde")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white.opacity(showSmallLines ? 0.5 : 0))
                Text(typed)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                Text("se va tu dinero?")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(showSmallLines ? 0.9 : 0))
                    .padding(.leading, Space.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)

        case .brand:
            VStack(alignment: .leading, spacing: Space.s) {
                Text("con")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white.opacity(showSmallLines ? 0.6 : 0))
                Text(typed)
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .ticker:
            VStack(alignment: .leading, spacing: Space.s) {
                Text("con")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                Text("PLATA")
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundStyle(.white)
                // Ticker: una frase a la vez, sube y aparece.
                Text(verbs[tickerIndex % verbs.count])
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .id(tickerIndex)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, Space.xl)

        case .sweep:
            Color.clear
        }
    }

    // MARK: - Timeline

    private func run() async {
        // Fase 1: escribir la línea grande.
        await type("¿CANSADO de no saber", speed: 0.045)
        withAnimation(.smooth(duration: 0.5)) { showSmallLines = true }
        try? await sleep(1.6)

        // Borrar y pasar a marca.
        withAnimation(.easeIn(duration: 0.3)) { showSmallLines = false }
        await erase()
        phase = .brand
        typed = ""
        withAnimation(.smooth(duration: 0.4)) { showSmallLines = true }
        await type("PLATA", speed: 0.09)
        try? await sleep(0.9)

        // Ticker.
        phase = .ticker
        try? await sleep(0.3)
        for i in 0..<verbs.count {
            withAnimation(.smooth(duration: 0.45)) { tickerIndex = i }
            try? await sleep(0.85)
        }
        try? await sleep(0.2)

        // Barrido con la moneda.
        phase = .sweep
        withAnimation(.easeOut(duration: 0.2)) { coinVisible = true }
        try? await sleep(0.2)
        withAnimation(.timingCurve(0.3, 0.0, 0.2, 1.0, duration: 1.1)) {
            coinProgress = 1
        }
        try? await sleep(1.15)
        finish()
    }

    /// Revela `text` carácter a carácter en `typed`.
    private func type(_ text: String, speed: Double) async {
        for ch in text {
            typed.append(ch)
            try? await sleep(speed)
        }
    }

    /// Borra `typed` de atrás hacia adelante (rápido).
    private func erase() async {
        while !typed.isEmpty {
            typed.removeLast()
            try? await sleep(0.018)
        }
    }

    private func sleep(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func finish() {
        onFinish()
    }
}
