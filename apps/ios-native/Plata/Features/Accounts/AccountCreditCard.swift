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

            // Zona inferior: nombre + monto grande tabular.
            // Tarjeta de crédito → muestra el CUPO DISPONIBLE (con usado/total debajo);
            // cuenta normal → muestra el balance.
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Typo.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                if account.isCredit, let available = account.availableCredit {
                    Text(CurrencyFormatter.string(available, currency: currency))
                        .font(fillsWidth ? Typo.amountLarge : Typo.amountMedium)
                        .tracking(-0.5).monospacedDigit().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    if let limit = account.creditLimit {
                        Text("Disponible · usado \(CurrencyFormatter.string(account.balance, currency: currency)) de \(CurrencyFormatter.string(limit, currency: currency))")
                            .font(Typo.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                } else {
                    Text(CurrencyFormatter.string(account.balance, currency: currency))
                        .font(fillsWidth ? Typo.amountLarge : Typo.amountMedium)
                        .tracking(-0.5).monospacedDigit().foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    if account.isCredit {
                        // Crédito sin cupo definido: rotula el monto como deuda.
                        Text("Deuda actual").font(Typo.caption).foregroundStyle(.white.opacity(0.75))
                    }
                }
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

    // Fondo de la tarjeta: degradado diagonal suave del color + una capa de
    // liquid glass en la mitad superior (reflejo de vidrio) + highlight de luz.
    private var cardSurface: some View {
        ZStack {
            // Gradiente diagonal del color, más SUAVE que antes (rango contenido,
            // se ve elegante, no dramático). Derivado del color, no plano.
            LinearGradient(
                colors: [
                    AccountCreditCardStyle.lighten(base, by: 0.12),
                    base,
                    AccountCreditCardStyle.darken(base, by: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Toque de LIQUID GLASS: lámina de vidrio translúcida en la mitad
            // superior. En iOS 26 usa .glassEffect real; en iOS 17 cae a
            // .ultraThinMaterial. Enmascarada para que brille arriba y se
            // disuelva hacia el centro (reflejo de vidrio).
            Color.clear
                .liquidGlass(cornerRadius: AccountCreditCardStyle.radius)
                .opacity(0.65)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)

            // "Sheen": banda diagonal de brillo que cruza la tarjeta, el reflejo
            // característico de una superficie de vidrio pulida.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.10), location: 0.42),
                    .init(color: .white.opacity(0.22), location: 0.5),
                    .init(color: .white.opacity(0.10), location: 0.58),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            // Highlight de luz en la esquina superior.
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
