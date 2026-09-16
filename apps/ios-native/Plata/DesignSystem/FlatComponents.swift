import SwiftUI

// Componentes de layout PLANO (sin containers/cards). La jerarquía se construye
// con tipografía, espaciado y separadores hairline — el estilo del diseño legacy
// y de apps como Monarch/YNAB. Reemplazan el uso de Card en casi toda la app.
// (Card se reserva SOLO para superficies que de verdad son "tarjetas", como las
// tarjetas de cuenta estilo crédito.)

// MARK: - Sección plana (header + filas con separadores, sin fondo)

/// Agrupa filas bajo un header de sección (overline en mayúsculas) con una acción
/// opcional a la derecha. Las filas se separan con hairlines sutiles, no con un
/// container. Pásale un ForEach o filas directamente.
struct PlainSection<Content: View>: View {
    let title: String?
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let title {
                HStack {
                    Text(title.uppercased())
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
            VStack(spacing: 0) { content }
        }
    }
}

/// Separador hairline entre filas de una sección plana.
struct RowDivider: View {
    var leadingInset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Palette.stroke.opacity(0.7))
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

/// Aplica el divisor entre elementos de un ForEach, salvo el último.
/// Uso: dentro de PlainSection, `PlainList(items) { item in FilaX(item) }`.
struct PlainList<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    let data: Data
    var dividerInset: CGFloat = 56   // alineado tras un ícono de 40 + gap
    @ViewBuilder let row: (Data.Element) -> RowContent

    /// `data` posicional (sin etiqueta) para leerse como una lista: `PlainList(items) { … }`.
    init(_ data: Data, dividerInset: CGFloat = 56, @ViewBuilder row: @escaping (Data.Element) -> RowContent) {
        self.data = data
        self.dividerInset = dividerInset
        self.row = row
    }

    var body: some View {
        let last = data.last?.id
        ForEach(data) { item in
            row(item)
            if item.id != last {
                RowDivider(leadingInset: dividerInset)
            }
        }
    }
}

// MARK: - Fila plana genérica (ícono + título/subtítulo + trailing)

/// Fila estándar: ícono a la izquierda, título + subtítulo, y contenido a la
/// derecha (monto, chevron…). Sin fondo — vive dentro de una PlainSection.
struct PlainRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.m) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Space.s)
            trailing
        }
        .padding(.vertical, Space.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Stat inline (dato con label, sin card)

/// Dos o más datos alineados a la izquierda, en línea, bajo un número grande —
/// como el "Ingresos / Gastos" del dashboard legacy. Sin cards.
struct InlineStat: View {
    let label: String
    let amount: Double
    var currency: String = "COP"
    var tint: Color = Palette.ink
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Space.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text(CurrencyFormatter.string(amount, currency: currency))
                .font(Typo.amount)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Logo/ícono de fila (tamaño consistente, no apretado)

/// Contenedor visual para el logo de una app o el ícono de categoría en una fila.
/// Da un tamaño generoso y consistente (legacy los mostraba pequeños y apretados;
/// aquí respiran). Prioriza el logo de app; si no, el ícono de categoría en color.
struct RowLeadingIcon: View {
    /// Logo de app (Netflix, Spotify…): a color, sobre fondo neutro. Prioridad 1.
    var logo: Image? = nil
    /// Ícono de categoría de Hugeicons (template, se tiñe con `color`). Prioridad 2.
    var categoryIcon: Image? = nil
    /// SF Symbol de respaldo si no hay logo ni Hugeicon. Prioridad 3.
    var systemName: String = "circle.grid.2x2.fill"
    var color: Color = Palette.accent
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let logo {
                logo
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)         // aire alrededor del logo
                    .frame(width: size, height: size)
                    .background(Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else if let categoryIcon {
                // Hugeicon outline teñido con el color de la categoría, mismo
                // tratamiento (color + fondo tinte) que el SF Symbol de respaldo.
                categoryIcon
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .padding(size * 0.24)         // outline delgado: más aire
                    .frame(width: size, height: size)
                    .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: size, height: size)
                    .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            }
        }
    }
}
