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

// MARK: - Orbe "interpretando"

struct WorkingOrb: View {
    var tint: Color = Palette.accent
    var size: CGFloat = 96

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let rotation = Angle.degrees((t * 90).truncatingRemainder(dividingBy: 360))
            // Respiración suave (escala 0.94…1.06).
            let breathe = 1 + 0.06 * sin(t * 2.2)

            ZStack {
                // Halo difuso que pulsa.
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .scaleEffect(breathe)
                    .blur(radius: 12)

                // Cuerpo del orbe: gradiente cónico girando.
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                tint, tint.opacity(0.35), Palette.onAccent.opacity(0.9),
                                tint.opacity(0.55), tint,
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(rotation)
                    // Brillo especular fijo encima (no rota): da volumen.
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    center: .init(x: 0.32, y: 0.28),
                                    startRadius: 0, endRadius: size * 0.55
                                )
                            )
                    )
                    .scaleEffect(breathe)
                    .shadow(color: tint.opacity(0.4), radius: 14, y: 4)
            }
            .frame(width: size * 1.5, height: size * 1.5)
        }
    }
}
