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
/// "mobile"): varios lóbulos de color en forma de campana `exp(-(|x|/spread)^curve)`
/// a lo largo del borde inferior, cuya altura sigue el nivel de audio, con un
/// bloom difuso detrás. Monocromático-violeta para armonizar con la marca.
struct ListeningWaveform: View {
    /// Nivel de audio 0…1 (RMS suavizado desde SpeechCapture).
    var level: Float

    // Lóbulos: cada uno con su color, posición horizontal relativa (-1…1) y peso.
    private let lobes: [(color: Color, x: Double, weight: Double)] = [
        (Color(red: 0.69, green: 0.55, blue: 1.0),  0.0, 1.0),   // centro (lavanda)
        (Color(red: 1.0,  green: 0.44, blue: 0.63), -0.42, 0.7), // rosa
        (Color(red: 0.35, green: 0.75, blue: 1.0),  0.42, 0.7),  // azul
        (Color(red: 0.66, green: 0.40, blue: 1.0), -0.8, 0.45),  // violeta
        (Color(red: 0.40, green: 0.85, blue: 0.95), 0.8, 0.45),  // aqua
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Nivel efectivo con piso de "respiración" para que nunca se vea muerto.
            let lvl = Double(max(0.08, level))

            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let baseY = h                       // el glow nace del borde inferior
                let ceiling = h * 0.9 * lvl         // altura máxima según el nivel
                let halfRange = w * 0.42

                ctx.blendMode = .plusLighter        // los lóbulos se suman como luz
                for lobe in lobes {
                    // Deriva horizontal lenta (flow) para que los colores "viajen".
                    let drift = sin(t * 0.6 + lobe.x * 2) * 10
                    let cx = w / 2 + CGFloat(lobe.x) * halfRange + drift
                    let peak = ceiling * lobe.weight * (0.85 + 0.15 * sin(t * 3 + lobe.x * 4))

                    drawLobe(ctx, centerX: cx, baseY: baseY, peak: peak,
                             spread: w * 0.16, color: lobe.color)
                }
            }
        }
    }

    /// Dibuja un lóbulo como una serie de elipses apiladas con opacidad
    /// decreciente (aproxima el bloom gaussiano del original sin filtros SVG).
    private func drawLobe(_ ctx: GraphicsContext, centerX: CGFloat, baseY: CGFloat,
                          peak: CGFloat, spread: CGFloat, color: Color) {
        guard peak > 1 else { return }
        let layers = 5
        for i in 0..<layers {
            let f = CGFloat(i) / CGFloat(layers - 1)      // 0…1 (adentro→afuera)
            let ellipseW = spread * (0.8 + 1.6 * f)
            let ellipseH = peak * (0.6 + 0.9 * f)
            // Opacidad contenida para que la suma (plusLighter) no queme el centro
            // a blanco y los colores sigan legibles.
            let alpha = (0.28 - 0.22 * f) * Double(min(1, peak / 40))
            let rect = CGRect(x: centerX - ellipseW, y: baseY - ellipseH,
                              width: ellipseW * 2, height: ellipseH * 2)
            ctx.fill(Ellipse().path(in: rect), with: .color(color.opacity(alpha)))
        }
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
