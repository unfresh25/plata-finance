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

    @State private var isOpen = false

    // Orden visual: la primera del array queda pegada al FAB (más abajo). Se
    // pintan de abajo hacia arriba, como en el legacy (Transacción primero).
    private let actions: [AddDestination] = [
        .transaction, .budget, .shoppingList, .goal, .debt, .account, .recurring,
    ]

    var body: some View {
        ZStack {
            // Backdrop: oscurece y captura el tap para cerrar. Solo con el menú
            // abierto; ocupa toda la pantalla.
            if isOpen {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            // Columna de acciones (speed-dial) + FAB + micrófono, anclada
            // explícitamente abajo-derecha ocupando toda el área disponible.
            VStack(alignment: .trailing, spacing: Space.m) {
                if isOpen {
                    ForEach(actions) { action in
                        SpeedDialRow(destination: action) {
                            select(action)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }

                // Chat IA + micrófono: accesos rápidos. Se ocultan con el menú
                // abierto para no competir con la "×".
                if !isOpen {
                    ChatFloatingButton { onChat() }
                        .transition(.scale.combined(with: .opacity))
                    MicFloatingButton { onVoice() }
                        .transition(.scale.combined(with: .opacity))
                }

                // FAB principal.
                PlusFloatingButton(isOpen: isOpen) {
                    isOpen ? close() : open()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, Space.l)
            // Justo encima de la cápsula del tab bar flotante (altura real ~64pt
            // + su padding inferior), con un aire pequeño. Antes 96+ dejaba un
            // hueco enorme.
            .padding(.bottom, 72)
        }
        // No interceptar toques fuera de los botones cuando el menú está cerrado.
        .allowsHitTesting(true)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isOpen)
    }

    // MARK: - Acciones

    private func open() { isOpen = true }
    private func close() { isOpen = false }

    private func select(_ destination: AddDestination) {
        close()
        // Deja arrancar el cierre antes de presentar el add (evita solaparse).
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

// MARK: - Botón de chat IA flotante

private struct ChatFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("GenerateIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Palette.onAccent)
                .frame(width: 56, height: 56)
                .background(Palette.accent, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .contentShape(Circle())
        }
        .pressable(scale: 0.9)
        .accessibilityLabel("Preguntarle a Plata IA")
    }
}

// MARK: - Botón de micrófono flotante

private struct MicFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 56, height: 56)
                .background(Palette.accent, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                .contentShape(Circle())
        }
        .pressable(scale: 0.9)
        .accessibilityLabel("Dictar movimiento")
    }
}
