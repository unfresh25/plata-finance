import SwiftUI

// Animaciones del dictado por voz.
//   ListeningWaveform — barras verticales que reaccionan al nivel de audio en
//     vivo mientras el usuario habla (fase "escuchando").
//   WorkingOrb — orbe con gradiente que rota y respira mientras el backend
//     interpreta el texto (fase "interpretando").
// Ambas usan TimelineView para un reloj continuo sincronizado con la pantalla,
// y solo animan transform/opacity (baratas para el compositor).

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
                let peak = h * 0.9 * lvl
                let spread = w * 0.26                 // ancho del domo
                // Deriva lenta del gradiente: los colores "viajan" (flow).
                let shift = CGFloat(sin(t * 0.35)) * w * 0.12

                // UNA franja arcoíris continua, enmascarada por UNA campana suave,
                // muy difuminada → halo blando de color (no lóbulos separados).
                LinearGradient(
                    colors: rainbow,
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: w * 1.25)
                .offset(x: shift)
                .frame(width: w)
                .mask(
                    BellShape(peak: peak, spread: spread,
                              breathe: CGFloat(0.9 + 0.1 * sin(t * 2.2)), curve: curve)
                )
                .blur(radius: 24)                     // el blur fuerte funde todo en un halo
                .frame(width: w, height: h, alignment: .bottom)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: lvl)
            }
        }
    }
}

// MARK: - Forma de campana (la silueta del glow)

/// Domo de campana `(exp(-(|x|/s)^curve) - borde)/(1-borde)` pegado al borde
/// inferior — la máscara que le da forma al halo de color.
private struct BellShape: Shape {
    var peak: CGFloat
    var spread: CGFloat
    var breathe: CGFloat
    var curve: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
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

// MARK: - Orbe "interpretando" (estado "working" de thinking-orbs)

/// Puerto a SwiftUI del estado "working" de thinking-orbs (libraries.dev/orbs):
/// partículas en órbitas 3D inclinadas, dibujadas como puntos monocromáticos
/// sobre un Canvas 2D (igual que la librería original). La profundidad (z) modula
/// tamaño y opacidad para dar volumen esférico.
struct WorkingOrb: View {
    var tint: Color = Palette.accent
    var size: CGFloat = 120

    // Órbitas: cada una es un anillo de puntos con su inclinación y velocidad.
    private let rings: [Ring] = [
        Ring(tiltX: 1.15, tiltZ: 0.30, speed: 1.0, count: 14, phase: 0.0),
        Ring(tiltX: 0.55, tiltZ: -0.65, speed: -0.82, count: 12, phase: 1.7),
        Ring(tiltX: 1.4, tiltZ: 0.9, speed: 0.66, count: 10, phase: 3.4),
    ]

    private struct Ring {
        let tiltX: Double   // inclinación del plano de la órbita
        let tiltZ: Double
        let speed: Double   // rad/s (signo = sentido de giro)
        let count: Int
        let phase: Double
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.72

                // Recolectar puntos con su z (para pintar de atrás hacia adelante).
                var pts: [(p: CGPoint, z: Double, r: CGFloat)] = []
                for ring in rings {
                    for i in 0..<ring.count {
                        let a = ring.phase + t * ring.speed + Double(i) / Double(ring.count) * 2 * .pi
                        // Punto en el plano de la órbita (círculo unitario).
                        let ux = cos(a)
                        let uy = sin(a)
                        // Inclinar el plano en 3D (rotaciones simples).
                        let x = ux
                        let y = uy * cos(ring.tiltX)
                        let z = uy * sin(ring.tiltX) * cos(ring.tiltZ) + ux * sin(ring.tiltZ) * 0.4
                        let px = center.x + CGFloat(x) * radius
                        let py = center.y + CGFloat(y) * radius
                        pts.append((CGPoint(x: px, y: py), z, 0))
                    }
                }
                // Pintar de atrás (z pequeño) a adelante (z grande).
                for item in pts.sorted(by: { $0.z < $1.z }) {
                    let depth = (item.z + 1) / 2                 // 0…1
                    let dotR = 1.5 + 3.0 * depth                  // más grande al frente
                    let alpha = 0.25 + 0.75 * depth               // más opaco al frente
                    let rect = CGRect(x: item.p.x - dotR, y: item.p.y - dotR, width: dotR * 2, height: dotR * 2)
                    ctx.fill(Circle().path(in: rect), with: .color(tint.opacity(alpha)))
                }
            }
            .frame(width: size, height: size)
        }
    }
}
