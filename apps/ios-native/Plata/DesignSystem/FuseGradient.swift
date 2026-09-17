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
                // Opacidad contenida (máx ~0.72) para que se vea elegante, no
                // brillante ni saturado.
                LinearGradient(
                    stops: [
                        .init(color: color.opacity(0.72), location: 0.0),
                        .init(color: color.opacity(0.58), location: 0.32),
                        .init(color: color.opacity(0.28), location: 0.6),
                        .init(color: color.opacity(0.0), location: 0.88),
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Brillo diagonal MUY tenue dentro de la masa (volumen sutil).
                RadialGradient(
                    colors: [color.opacity(0.22), .clear],
                    center: .init(x: 0.75, y: 0.85),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.7
                )
            }
            .ignoresSafeArea()
        }
    }
}
