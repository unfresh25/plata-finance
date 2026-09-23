import SwiftUI

// FAB de acción flotante en la esquina inferior derecha (paridad con el
// FloatingMenu.tsx del legacy). Un botón "+" que despliega las 7 acciones de
// creación hacia arriba (speed-dial) con backdrop, stagger y rotación a "×".
// Encima del "+" flota un botón de micrófono para dictar desde cualquier
// pantalla (acceso rápido). No es un sheet: se anima sobre el contenido.
//
// Uso: se monta como overlay en MainTabView. `onSelect` recibe el destino
// elegido; `onVoice` abre el dictado.

struct FloatingActionMenu: View {
    var onSelect: (AddDestination) -> Void
    var onVoice: () -> Void
    var onChat: () -> Void = {}

    // En reposo solo se ve el "+". Al tocarlo → radial (voz/chat/crear).
    // "Crear" → speed-dial de las 7 acciones de creación (como antes).
    @State private var phase: Phase = .closed

    private enum Phase { case closed, radial, create }

    private let actions: [AddDestination] = [
        .transaction, .budget, .shoppingList, .goal, .wish, .debt, .account, .recurring,
    ]

    var body: some View {
        ZStack {
            // Backdrop mientras hay algo abierto.
            if phase != .closed {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            // Nivel 2: speed-dial de creación (las 7 acciones), como antes.
            if phase == .create {
                VStack(alignment: .trailing, spacing: Space.m) {
                    ForEach(actions) { action in
                        SpeedDialRow(destination: action) { select(action) }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, Space.l)
                .padding(.bottom, 72 + 68)   // encima del FAB
            }

            // Nivel 1: radial con 3 acciones alrededor del FAB.
            radialMenu
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, Space.l)
                .padding(.bottom, 72)
        }
        .allowsHitTesting(true)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: phase)
    }

    // Radial: 3 botones distribuidos en cuarto de círculo (arriba, arriba-izq,
    // izquierda) desde el FAB de la esquina inferior derecha.
    private var radialMenu: some View {
        ZStack {
            if phase == .radial {
                // Abanico arriba-izquierda: voz la más cercana al FAB (abajo),
                // luego chat, luego crear (la más alejada, arriba-izquierda).
                radialItem(icon: "mic.fill", label: "Dictar", angle: 90, action: { close(); onVoice() })
                radialItem(image: "GenerateIcon", label: "Plata IA", angle: 128, action: { close(); onChat() })
                radialItem(icon: "square.grid.2x2.fill", label: "Crear", angle: 166, action: { phase = .create })
            }
            // FAB principal (rota a × cuando hay algo abierto).
            PlusFloatingButton(isOpen: phase != .closed) {
                phase == .closed ? (phase = .radial) : close()
            }
        }
    }

    @ViewBuilder
    private func radialItem(icon: String? = nil, image: String? = nil, label: String,
                            angle: Double, action: @escaping () -> Void) -> some View {
        let radius: CGFloat = 92
        let rad = angle * .pi / 180
        // Abanico desde la esquina inf-der: ángulo 90°=arriba, 180°=izquierda.
        // dx = cos·r (0 a -r → izquierda), dy = -sin·r (siempre arriba).
        let dx = CGFloat(cos(rad)) * radius
        let dy = -CGFloat(sin(rad)) * radius
        Button(action: action) {
            Group {
                if let image {
                    Image(image).renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: icon ?? "circle").font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundStyle(Palette.onAccent)
            .frame(width: 52, height: 52)
            .background(Palette.accent, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        }
        .pressable(scale: 0.9)
        .offset(x: dx, y: dy)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel(label)
    }

    // MARK: - Acciones

    private func close() { phase = .closed }

    private func select(_ destination: AddDestination) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onSelect(destination)
        }
    }
}

// MARK: - Fila del speed-dial ([label] [botón circular])

private struct SpeedDialRow: View {
    let destination: AddDestination
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Text(destination.label)
                    .font(Typo.subhead.weight(.semibold))
                    .foregroundStyle(.white)
                    // Sin fondo: el texto vive sobre el backdrop oscuro del menú.
                    // Sombra sutil para legibilidad si queda sobre una zona clara.
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

                Image(systemName: destination.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 56, height: 56)
                    .background(destination.tint, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
        .pressable(scale: 0.94)
    }
}

// MARK: - FAB "+" (rota a × al abrir)

private struct PlusFloatingButton: View {
    let isOpen: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .rotationEffect(.degrees(isOpen ? 135 : 0))
                .frame(width: 56, height: 56)
                .background(Palette.accent, in: Circle())
                // Sombra neutra sutil (no glow de acento): elevación sin ruido.
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        }
        .pressable(scale: 0.9)
        .accessibilityLabel(isOpen ? "Cerrar menú" : "Crear")
    }
}

