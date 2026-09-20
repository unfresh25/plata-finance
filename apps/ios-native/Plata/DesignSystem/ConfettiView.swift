import SwiftUI

// Confeti de celebración (sin dependencias). Se dispara al `trigger`: lanza
// partículas que caen con gravedad y rotan, y desaparecen solas. Overlay puro,
// no bloquea interacción.

struct ConfettiView: View {
    /// Cambiar este valor (p. ej. incrementar) dispara una nueva ráfaga.
    var trigger: Int
    var colors: [Color] = [
        Color(red: 0.49, green: 0.42, blue: 1.0),   // violeta
        Color(red: 0.35, green: 0.85, blue: 0.55),  // verde
        Color(red: 1.0, green: 0.75, blue: 0.25),   // amarillo
        Color(red: 1.0, green: 0.44, blue: 0.63),   // rosa
        Color(red: 0.35, green: 0.75, blue: 1.0),   // azul
    ]

    @State private var pieces: [Piece] = []
    @State private var startedAt: Date? = nil

    private struct Piece: Identifiable {
        let id = Int.random(in: 0..<1_000_000)
        let x: CGFloat            // 0…1 posición horizontal inicial
        let color: Color
        let size: CGFloat
        let vx: CGFloat           // deriva horizontal
        let delay: Double
        let spin: Double
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date
                Canvas { ctx, size in
                    guard let start = startedAt else { return }
                    let t = now.timeIntervalSince(start)
                    for p in pieces {
                        let pt = t - p.delay
                        guard pt >= 0 else { continue }
                        let g: CGFloat = 900          // gravedad px/s²
                        let y = 0.5 * g * CGFloat(pt * pt) - 250 * CGFloat(pt)
                        let x = p.x * size.width + p.vx * CGFloat(pt)
                        let opacity = max(0, 1 - pt / 2.2)
                        guard opacity > 0 else { continue }
                        var rect = ctx
                        rect.translateBy(x: x, y: y)
                        rect.rotate(by: .degrees(p.spin * pt * 180))
                        rect.opacity = opacity
                        let r = CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size*0.5)
                        rect.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in burst() }
        .onAppear { if trigger > 0 { burst() } }
    }

    private func burst() {
        pieces = (0..<90).map { _ in
            Piece(
                x: CGFloat.random(in: 0.2...0.8),
                color: colors.randomElement() ?? .purple,
                size: CGFloat.random(in: 7...13),
                vx: CGFloat.random(in: -120...120),
                delay: Double.random(in: 0...0.25),
                spin: Double.random(in: -1.5...1.5)
            )
        }
        startedAt = Date()
    }
}
