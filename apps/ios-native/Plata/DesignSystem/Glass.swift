import SwiftUI

// Liquid Glass (iOS 26). Envuelve las APIs nativas .glassEffect con fallback a
// un material translúcido en versiones anteriores, para que el design system
// aplique el look glass de forma consistente sin repetir #available por todos lados.

extension View {
    /// Aplica Liquid Glass sobre una forma redondeada. En iOS 26 usa el material
    /// vivo nativo; en versiones previas, un material translúcido equivalente.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = Radius.m, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }

    /// Glass en forma de cápsula (barras, botones pill).
    @ViewBuilder
    func liquidGlassCapsule(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }

    /// Glass teñido con un color (para botones de acento).
    @ViewBuilder
    func liquidGlassTinted(_ tint: Color, cornerRadius: CGFloat = Radius.pill, interactive: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(
                (interactive ? Glass.regular.interactive() : Glass.regular).tint(tint),
                in: shape
            )
        } else {
            self.background(tint, in: shape)
        }
    }
}

/// Contenedor que fusiona varios elementos glass cercanos (morphing) — iOS 26.
/// En versiones previas es un contenedor transparente sin efecto.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = Space.s
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
