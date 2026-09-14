import SwiftUI

// Pantalla de Cuentas: balance total agregado arriba y la lista de cuentas del
// hogar, cada una con su color e ícono propios. Desde aquí se añade una cuenta.

struct AccountsView: View {
    @Environment(AppState.self) private var app
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                AccountsTotalCard(total: app.totalBalance, currency: app.currency)

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel(text: "Cuentas")

                    if app.accounts.isEmpty {
                        AccountsEmptyState()
                    } else {
                        VStack(spacing: Space.m) {
                            ForEach(app.accounts) { account in
                                AccountsRow(account: account, currency: app.currency)
                            }
                        }
                    }
                }

                Button {
                    showingAdd = true
                } label: {
                    HStack(spacing: Space.s) {
                        Image(systemName: "plus")
                        Text("Añadir cuenta").font(Typo.headline)
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.l)
                    .background(Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .strokeBorder(Palette.stroke, lineWidth: 1)
                    )
                }
                .pressable()
            }
            .padding(Space.l)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Cuentas")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAdd) {
            AddAccountView()
        }
    }
}

// MARK: - Balance total

private struct AccountsTotalCard: View {
    let total: Double
    let currency: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Balance total")
                    .font(Typo.overline)
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkTertiary)
                AmountText(amount: total, currency: currency, font: Typo.amountHero(44))
            }
        }
    }
}

// MARK: - Fila de cuenta

private struct AccountsRow: View {
    let account: Account
    let currency: String

    private var tint: Color { AccountsColor.parse(account.color, fallbackFor: account.id) }

    var body: some View {
        Card(padding: Space.m) {
            HStack(spacing: Space.m) {
                CategoryIcon(systemName: account.type.sfSymbol, color: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                    Text(account.type.label)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Spacer(minLength: Space.s)

                AmountText(amount: account.balance, currency: currency, font: Typo.amount)
            }
        }
    }
}

// MARK: - Estado vacío

private struct AccountsEmptyState: View {
    var body: some View {
        Card {
            VStack(spacing: Space.s) {
                Image(systemName: "creditcard")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
                Text("Aún no tienes cuentas")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text("Añade tu primera cuenta para empezar a llevar tus finanzas.")
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
        }
    }
}

// MARK: - Parseo de color hex de la cuenta

/// Convierte el string `color` de una cuenta (ej. "#818CF8" o "818CF8") en un
/// `Color`. Si falla, cae a un color estable de la rueda derivado del id.
enum AccountsColor {
    static func parse(_ hex: String, fallbackFor id: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { // forma corta RGB → RRGGBB
            s = s.map { "\($0)\($0)" }.joined()
        }
        if s.count == 6, let value = UInt(s, radix: 16) {
            return Color(hex: value)
        }
        return Palette.categoryColor(for: abs(id.hashValue))
    }
}
