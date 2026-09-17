import SwiftUI

// Fondo estilo Fuse: un color de marca saturado ABAJO que sube y se desvanece
// hacia el fondo base (blanco en claro / negro en oscuro) por arriba. No es un
// halo radial pequeño — es una gran masa de color en la mitad inferior con un
// borde superior suave y difuso (como niebla de color subiendo). Un par de
// radiales tenues encima le dan volumen orgánico sin volverse arcoíris.

struct FuseGradient: View {
    /// Color base del degradado (por defecto el violeta de marca).
    var color: Color = Color(hex: 0x7050E8)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Fondo base (se ve por arriba, donde el color se desvanece).
                Palette.bg

                // Masa de color que sube desde abajo y muere hacia el centro-alto.
                LinearGradient(
                    stops: [
                        .init(color: color, location: 0.0),
                        .init(color: color.opacity(0.92), location: 0.35),
                        .init(color: color.opacity(0.5), location: 0.62),
                        .init(color: color.opacity(0.0), location: 0.9),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Brillo diagonal tenue dentro de la masa (da profundidad/volumen).
                RadialGradient(
                    colors: [color.opacity(0.55), .clear],
                    center: .init(x: 0.75, y: 0.80),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.75
                )
                .blendMode(.plusLighter)

                // Un lavanda más claro abajo-izquierda para que no sea plano.
                RadialGradient(
                    colors: [Color(hex: 0x9B84F0).opacity(0.40), .clear],
                    center: .init(x: 0.15, y: 0.95),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.6
                )
                .blendMode(.plusLighter)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Ticker vertical de palabras (Earn / Spend / Invest…)

/// Columna de palabras que rotan verticalmente; la central va nítida con su
/// ícono, las de arriba/abajo se desvanecen. Como el header de Fuse.
struct WordTicker: View {
    let words: [(text: String, symbol: String)]
    /// Índice activo; el caller lo avanza con un timer.
    let index: Int
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(-2...2, id: \.self) { offset in
                let i = ((index + offset) % words.count + words.count) % words.count
                let w = words[i]
                HStack(spacing: Space.s) {
                    if offset == 0 {
                        Image(systemName: w.symbol)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(tint)
                            .transition(.opacity)
                    }
                    Text(w.text)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(offset == 0 ? 1 : opacity(for: offset)))
                }
            }
        }
        .animation(.smooth(duration: 0.5), value: index)
    }

    private func opacity(for offset: Int) -> Double {
        switch abs(offset) {
        case 1: return 0.12
        default: return 0.05
        }
    }
}
