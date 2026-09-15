import SwiftUI

// MARK: - Card

/// Superficie base de la app. En iOS 26 usa Liquid Glass; el borde hairline se
/// conserva para definir el contorno. Radio grande, continuo.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.l
    var glass: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(CardSurface(glass: glass))
    }
}

/// Fondo de tarjeta: Liquid Glass o superficie sólida.
private struct CardSurface: ViewModifier {
    var glass: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
        if glass {
            content
                .liquidGlass(cornerRadius: Radius.m)
                .overlay(shape.strokeBorder(Palette.stroke.opacity(0.6), lineWidth: 1))
        } else {
            content
                .background(Palette.surface, in: shape)
                .overlay(shape.strokeBorder(Palette.stroke, lineWidth: 1))
        }
    }
}

// MARK: - Press feedback (Emil: scale 0.97 on press, ease-out)

/// Estilo de botón que escala ligeramente al presionar. Feedback instantáneo.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension View {
    /// Aplica feedback de press a cualquier vista tappable envuelta en Button.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableStyle(scale: scale))
    }
}

// MARK: - Botones

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Palette.ink
    var fg: Color = Palette.bg
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typo.headline)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
            .liquidGlassTinted(tint, cornerRadius: Radius.pill)
        }
        .pressable()
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Typo.headline)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.l)
            .liquidGlassCapsule(interactive: true)
        }
        .pressable()
    }
}

// MARK: - Pill toggle (expense / income / transfer)

struct PillToggle<T: Hashable>: View {
    let options: [(value: T, label: String, tint: Color)]
    @Binding var selection: T
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let isSelected = selection == opt.value
                Button {
                    withAnimation(Motion.ui) { selection = opt.value }
                } label: {
                    Text(opt.label)
                        .font(Typo.callout)
                        .foregroundStyle(isSelected ? Palette.bg : Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.m)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(opt.tint)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.surface, in: Capsule())
    }
}

// MARK: - Category chip (ícono en círculo de color)

struct CategoryIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

// MARK: - Progress ring (metas, presupuesto)

struct ProgressRing: View {
    var progress: Double // 0...1
    var color: Color = Palette.green
    var lineWidth: CGFloat = 12
    var size: CGFloat = 200

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.surfaceElevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.value, value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Amount display (monto formateado con signo y color)

struct AmountText: View {
    let amount: Double
    var currency: String = "COP"
    var font: Font = Typo.amount
    var signed: Bool = false          // muestra +/-
    var tintBySign: Bool = false      // verde/rojo según signo

    var body: some View {
        Text(formatted)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private var color: Color {
        guard tintBySign else { return Palette.ink }
        return amount >= 0 ? Palette.positive : Palette.negative
    }

    private var formatted: String {
        let value = signed ? amount : abs(amount)
        return CurrencyFormatter.string(value, currency: currency, showSign: signed)
    }
}

// MARK: - Section header (overline en mayúsculas)

struct SectionLabel: View {
    let text: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Typo.overline)
                .tracking(0.8)
                .foregroundStyle(Palette.inkTertiary)
            Spacer()
            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)
            }
        }
    }
}
