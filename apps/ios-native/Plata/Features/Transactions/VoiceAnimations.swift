import SwiftUI

// Animaciones del dictado por voz.
//   ListeningWaveform — barras verticales que reaccionan al nivel de audio en
//     vivo mientras el usuario habla (fase "escuchando").
//   WorkingOrb — orbe con gradiente que rota y respira mientras el backend
//     interpreta el texto (fase "interpretando").
// Ambas usan TimelineView para un reloj continuo sincronizado con la pantalla,
// y solo animan transform/opacity (baratas para el compositor).

// MARK: - Waveform de escucha

struct ListeningWaveform: View {
    /// Nivel de audio 0…1 (RMS suavizado desde SpeechCapture).
    var level: Float
    var barCount: Int = 5
    var tint: Color = Palette.accent

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(tint)
                        .frame(width: 8, height: barHeight(index: i, time: t))
                }
            }
            .frame(height: 96)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: level)
        }
    }

    /// Cada barra oscila con una fase propia; la amplitud la marca el nivel de
    /// audio. Con nivel 0 quedan en una altura mínima (barras vivas, no muertas).
    private func barHeight(index: Int, time: Double) -> CGFloat {
        let base: CGFloat = 12
        let maxExtra: CGFloat = 72
        // Onda sinusoidal por barra, desfasada, modulada por el nivel.
        let phase = time * 5.5 + Double(index) * 0.9
        let wave = (sin(phase) + 1) / 2                     // 0…1
        let lvl = CGFloat(max(0.06, level))                 // piso para que respire
        let amp = lvl * (0.4 + 0.6 * CGFloat(wave))
        return base + maxExtra * amp
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
