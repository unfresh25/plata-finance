import SwiftUI

// Fondo "aurora" estilo Fuse: tres RadialGradient superpuestos (color → clear)
// con centros, radios y opacidades distintas, que emergen desde arriba sobre el
// fondo base y se desvanecen hacia el centro. Los tres tonos son variantes del
// mismo color de marca, así el degradado se lee como UN color con profundidad
// (no arcoíris). Se puede ocultar (al abrir teclado) con una transición suave.

struct AuroraBackground: View {
    /// Tonos del degradado. Por defecto, tres variantes del violeta de marca.
    var top: Color = Color(hex: 0x7050E8)     // violeta de marca
    var mid: Color = Color(hex: 0x9B84F0)     // lavanda claro
    var low: Color = Color(hex: 0x5B3FD0)     // índigo profundo
    /// Intensidad global (0…1). Más bajo = más sutil.
    var intensity: Double = 0.55

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Palette.bg

                // Capa 1: gran halo desde el borde superior.
                RadialGradient(
                    colors: [top.opacity(intensity), .clear],
                    center: .init(x: 0.30, y: -0.05),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.95
                )
                // Capa 2: acento lavanda arriba a la derecha.
                RadialGradient(
                    colors: [mid.opacity(intensity * 0.85), .clear],
                    center: .init(x: 0.90, y: 0.05),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.70
                )
                // Capa 3: base índigo tenue, empuja profundidad al centro-alto.
                RadialGradient(
                    colors: [low.opacity(intensity * 0.6), .clear],
                    center: .init(x: 0.55, y: 0.28),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.55
                )
                .blendMode(.plusLighter)
            }
            .ignoresSafeArea()
        }
    }
}
