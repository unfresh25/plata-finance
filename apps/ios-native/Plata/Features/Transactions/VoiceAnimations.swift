import SwiftUI

// Animaciones del dictado por voz (puerto del efecto "voice-glow" de libraries.dev).
//   ListeningWaveform — halo arcoíris en el borde inferior que florece con la voz
//     al escuchar; al procesar (processing: true) se recoge en un beam compacto
//     que se balancea de lado a lado.
//   MicPulse — el micrófono central (reposo / grabando).
// Usa TimelineView para un reloj continuo y anima transform/opacity.

// MARK: - Glow de escucha (puerto del efecto "voice-glow" de libraries.dev)

/// Beam de sonido centrado que sube y florece con la voz (voice-glow, tipo
/// "mobile"). Cada lóbulo de color es una CURVA DE CAMPANA continua
/// `(exp(-(|x|/s)^curve) - borde) / (1 - borde)` (la fórmula real de la librería),
/// rellena con un gradiente vertical hacia transparente y con blur real para el
/// bloom (las 3 capas del original: bloom difuso + luz interior + núcleo). Los
/// colores se suman como luz y derivan lateralmente (flow) mientras se habla.
struct ListeningWaveform: View {
    /// Nivel de audio 0…1 (RMS suavizado desde SpeechCapture).
    var level: Float
    /// Modo "processing": el glow se recoge en un beam compacto que se balancea
    /// de lado a lado (estado processing de VoiceBeam).
    var processing: Bool = false

    private let curve: Double = 1.8   // exponente de la campana (más = domo, menos = pico)

    // Arcoíris continuo: un solo gradiente horizontal (rosa→violeta→azul→verde→aqua).
    private let rainbow: [Color] = [
        Color(red: 1.0,  green: 0.44, blue: 0.63),  // rosa
        Color(red: 0.72, green: 0.42, blue: 1.0),   // violeta
        Color(red: 0.40, green: 0.55, blue: 1.0),   // azul
        Color(red: 0.35, green: 0.85, blue: 0.85),  // aqua/verde
        Color(red: 0.55, green: 0.60, blue: 1.0),   // periwinkle
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let lvl = CGFloat(max(0.12, level))

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Geometría según el modo.
                let peak: CGFloat = processing ? h * 0.5 : h * 0.55 * lvl
                let spread: CGFloat = processing ? w * 0.14 : w * 0.3  // beam angosto al procesar
                // Balanceo lado a lado al procesar (eased en cada extremo), o
                // deriva lenta del gradiente al escuchar.
                let sweep = processing ? sweepOffset(t) * w * 0.35 : 0
                let shift = processing ? sweep : CGFloat(sin(t * 0.35)) * w * 0.12

                LinearGradient(
                    colors: rainbow,
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: w * 1.25)
                .offset(x: CGFloat(sin(t * 0.35)) * w * 0.12)   // los colores fluyen dentro
                .frame(width: w)
                .mask(
                    BellShape(peak: peak, spread: spread, centerOffset: shift,
                              breathe: CGFloat(0.9 + 0.1 * sin(t * 2.2)), curve: curve)
                )
                .blur(radius: processing ? 18 : 24)
                .frame(width: w, height: h, alignment: .bottom)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lvl)
            }
        }
    }

    /// Posición del beam al procesar, con la fórmula EXACTA de VoiceBeam:
    ///   _ = t / duration ;  G = floor(_) ;  U = _ - G
    ///   D = U<0.5 ? 0.5·(2U)^E : 1 - 0.5·(2-2U)^E     (ease-in-out por potencia)
    ///   C = G par ? 2D-1 : 1-2D                        (alterna dirección, continuo)
    /// Da un vaivén literal de un lado a otro, eased en cada extremo, sin saltos.
    private func sweepOffset(_ t: Double) -> CGFloat {
        let duration = 1.1                              // processingDuration (s por pasada)
        let e = 2.1                                     // processingCurve
        let n = t / duration
        let g = floor(n)
        let u = n - g
        let d = u < 0.5 ? 0.5 * pow(2 * u, e) : 1 - 0.5 * pow(2 - 2 * u, e)
        let c = Int(g) % 2 == 0 ? (2 * d - 1) : (1 - 2 * d)
        return CGFloat(c)
    }
}

// MARK: - Forma de campana (la silueta del glow)

/// Domo de campana `(exp(-(|x|/s)^curve) - borde)/(1-borde)` pegado al borde
/// inferior — la máscara que le da forma al halo de color.
private struct BellShape: Shape {
    var peak: CGFloat
    var spread: CGFloat
    var centerOffset: CGFloat = 0   // desplazamiento horizontal del domo (barrido)
    var breathe: CGFloat
    var curve: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX + centerOffset
        let baseY = rect.maxY
        let h = peak * breathe
        let s = max(1, spread)
        let span = s * 3.2
        let edge = exp(-pow(Double(span / s), curve))
        p.move(to: CGPoint(x: rect.minX, y: baseY))
        p.addLine(to: CGPoint(x: cx - span, y: baseY))
        let steps = 80
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let x = -span + CGFloat(f) * span * 2
            let n = Double(x / s)
            let o = exp(-pow(abs(n), curve))
            let bell = max(0, (o - edge) / (1 - edge))
            p.addLine(to: CGPoint(x: cx + x, y: baseY - h * CGFloat(bell)))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: baseY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Micrófono central (reposo / grabando)

/// Botón de micrófono. En reposo, estático. Grabando, pulsa suave con el nivel
/// de audio (el glow reactivo principal vive en el borde inferior, VoiceBeam).
struct MicPulse: View {
    var active: Bool
    var level: Float
    var tint: Color = Palette.accent

    var body: some View {
        let scale = active ? 1 + CGFloat(level) * 0.12 : 1
        Circle()
            .fill(tint.opacity(active ? 1 : 0.9))
            .frame(width: 96, height: 96)
            .overlay(
                Image(systemName: "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
            )
            .scaleEffect(scale)
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: level)
    }
}
