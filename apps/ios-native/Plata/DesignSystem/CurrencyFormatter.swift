import Foundation

/// Formateo de moneda consistente en toda la app. Sin decimales cuando es
/// entero, hasta 2 cuando hace falta — como el formatCurrency del core actual.
enum CurrencyFormatter {
    static func string(_ amount: Double, currency: String = "COP", showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.locale = Locale(identifier: "es_CO")

        let base = formatter.string(from: NSNumber(value: abs(amount))) ?? "\(amount)"
        guard showSign else { return base }
        return (amount >= 0 ? "+" : "−") + base
    }

    /// Versión compacta para tarjetas estrechas: 2.5M, 1.5K.
    static func compact(_ amount: Double) -> String {
        let a = abs(amount)
        let sign = amount < 0 ? "−" : ""
        if a >= 1_000_000 { return "\(sign)\(trim(a / 1_000_000))M" }
        if a >= 1_000 { return "\(sign)\(trim(a / 1_000))K" }
        return "\(sign)\(trim(a))"
    }

    private static func trim(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }
}
