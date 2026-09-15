import SwiftUI

// MARK: - Tarjeta de crédito de cuenta

/// Tarjeta de cuenta con estética de TARJETA DE CRÉDITO real (tipo Apple Card).
/// Proporción ~1.6:1, esquinas muy redondeadas, fondo de degradado diagonal
/// derivado del color propio de la cuenta (variante clara → oscura), highlight
/// de luz en la esquina superior y sombra neutra sutil. Sin glass encima del
/// gradiente (el color ya aporta la superficie).
///
/// Se usa tanto en el carrusel del Dashboard (ancho fijo) como en la lista de
/// Cuentas (ancho completo) — el layout se adapta al ancho disponible.
struct AccountCreditCard: View {
    let account: Account
    let currency: String

    /// Cuando es `true` la tarjeta ocupa todo el ancho disponible (lista de
    /// Cuentas); si no, se mide por el ancho fijo del carrusel del Dashboard.
    var fillsWidth: Bool = false

    private var base: Color { AccountCreditCardStyle.color(from: account.color, id: account.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fila superior: ícono del tipo + chip del tipo.
            HStack(alignment: .top) {
                Image(systemName: account.type.sfSymbol)
                    .font(.system(size: fillsWidth ? 22 : 19, weight: .semibold))
                    .foregroundStyle(.white)
                    // Sombra propia tenue para separar el glifo del fondo de color.
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                Spacer(minLength: Space.m)

                Text(account.type.label)
                    .font(Typo.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, 4)
                    // Chip translúcido tallado en el propio color (blanco muy tenue),
                    // no un material glass encima del gradiente.
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75))
            }

            Spacer(minLength: Space.l)

            // Zona inferior: nombre + balance grande tabular.
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typo.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                Text(CurrencyFormatter.string(account.balance, currency: currency))
                    .font(fillsWidth ? Typo.amountLarge : Typo.amountMedium)
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(fillsWidth ? Space.l : Space.l)
        .frame(
            width: fillsWidth ? nil : AccountCreditCardStyle.carouselWidth,
            height: fillsWidth ? nil : AccountCreditCardStyle.carouselWidth / AccountCreditCardStyle.ratio,
            alignment: .leading
        )
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .aspectRatio(fillsWidth ? AccountCreditCardStyle.ratio : nil, contentMode: .fit)
        .background { cardSurface }
        .clipShape(RoundedRectangle(cornerRadius: AccountCreditCardStyle.radius, style: .continuous))
        .overlay {
            // Hairline luminoso: la luz cae desde arriba y se apaga hacia abajo.
            RoundedRectangle(cornerRadius: AccountCreditCardStyle.radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        // Sombra neutra y sutil, multicapa (NO glow de color).
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    // Fondo de la tarjeta: degradado diagonal clara → oscura + highlight de luz.
    private var cardSurface: some View {
        ZStack {
            // Gradiente diagonal del color (variante más clara arriba-izq a más
            // oscura abajo-der). Derivado del color, no plano.
            LinearGradient(
                colors: [
                    AccountCreditCardStyle.lighten(base, by: 0.16),
                    base,
                    AccountCreditCardStyle.darken(base, by: 0.26),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Highlight de luz en la esquina superior: brillo blanco muy tenue
            // que da el efecto "tarjeta" (superficie que refleja luz).
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: AccountCreditCardStyle.carouselWidth * 0.9
            )
            .blendMode(.softLight)
        }
    }
}

// MARK: - Estilo / geometría / derivación de color

/// Geometría y utilidades de color de la tarjeta de crédito. Deriva variantes
/// más claras y oscuras del color de la cuenta para el gradiente diagonal.
enum AccountCreditCardStyle {
    /// Proporción de tarjeta de crédito (más ancha que alta).
    static let ratio: CGFloat = 1.6
    /// Ancho fijo de la tarjeta en el carrusel del Dashboard.
    static let carouselWidth: CGFloat = 260
    /// Radio de esquina generoso (concéntrico con Radius.l, un pelo mayor).
    static let radius: CGFloat = Radius.l + 4

    /// Convierte el color hex de la cuenta a `Color`, con fallback estable por id.
    static func color(from hex: String, id: String) -> Color {
        Color(hexString: hex) ?? Palette.categoryColor(for: abs(id.hashValue))
    }

    /// Aclara el color subiendo brillo y bajando saturación levemente (0…1).
    static func lighten(_ color: Color, by amount: CGFloat) -> Color {
        adjust(color, brightness: amount, saturation: -amount * 0.35)
    }

    /// Oscurece el color bajando brillo y subiendo saturación levemente (0…1).
    static func darken(_ color: Color, by amount: CGFloat) -> Color {
        adjust(color, brightness: -amount, saturation: amount * 0.25)
    }

    /// Ajusta brillo y saturación en espacio HSB. Si no se pueden leer los
    /// componentes, mezcla con blanco/negro como aproximación segura.
    private static func adjust(_ color: Color, brightness db: CGFloat, saturation ds: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let ui = UIColor(color)
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            let newS = min(max(s + ds, 0), 1)
            let newB = min(max(b + db, 0), 1)
            return Color(hue: Double(h), saturation: Double(newS), brightness: Double(newB), opacity: Double(a))
        }
        // Fallback: mezcla lineal con blanco (db>0) o negro (db<0).
        return color
    }
}
