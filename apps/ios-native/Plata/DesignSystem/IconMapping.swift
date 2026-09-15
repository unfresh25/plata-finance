import SwiftUI

// Mapeo de los íconos del backend (nombres tipo 'hamburger-01', heredados del
// IconDictionary de la app RN con Hugeicons) a SF Symbols nativos. Para íconos
// no mapeados, un fallback razonable por palabra clave y, en último caso, un
// símbolo genérico. Mantiene consistencia visual con SF Symbols en toda la app.

enum IconMapping {
    /// SF Symbol para un nombre de ícono del backend.
    static func sfSymbol(for name: String?) -> String {
        guard let raw = name?.lowercased(), !raw.isEmpty else { return "circle.grid.2x2.fill" }
        if let exact = table[raw] { return exact }
        // Fallback por palabra clave contenida.
        for (key, symbol) in keywordTable where raw.contains(key) {
            return symbol
        }
        return "circle.grid.2x2.fill"
    }

    // Mapeo directo de los slugs conocidos del IconDictionary original.
    private static let table: [String: String] = [
        // Comida
        "hamburger-01": "fork.knife", "coffee-01": "cup.and.saucer.fill",
        "natural-food": "leaf.fill", "pizza-01": "fork.knife", "drink": "wineglass.fill",
        "croissant": "birthday.cake.fill", "candy": "birthday.cake.fill",
        // Transporte
        "taxi": "car.fill", "fuel-station": "fuelpump.fill", "bus-01": "bus.fill",
        "airplane-01": "airplane", "car-01": "car.fill", "motorbike-02": "bicycle",
        "bicycle": "bicycle", "parking-meter": "parkingsign",
        // Hogar / servicios
        "home-01": "house.fill", "invoice-01": "doc.text.fill", "wifi-02": "wifi",
        "wrench-01": "wrench.and.screwdriver.fill", "sofa-01": "sofa.fill",
        "washing-machine": "washer.fill", "paint-brush-02": "paintbrush.fill",
        // Salud
        "hospital-01": "cross.fill", "medicine-02": "pills.fill",
        "dumbbell-01": "dumbbell.fill", "mentoring": "figure.2",
        "dental-tooth": "cross.case.fill", "glasses": "eyeglasses",
        "first-aid-kit": "cross.case.fill",
        // Entretenimiento
        "tv-01": "tv.fill", "game-controller-01": "gamecontroller.fill",
        "theater": "theatermasks.fill", "music-note-01": "music.note",
        "book-01": "book.fill", "volleyball": "volleyball.fill", "ticket-01": "ticket.fill",
        // Ropa / compras
        "t-shirt": "tshirt.fill", "running-shoes": "shoe.fill", "watch-01": "applewatch",
        "smart-phone-01": "iphone", "hair-dryer": "wind", "bird": "bird.fill",
        "baby-01": "figure.and.child.holdinghands",
        // Educación / trabajo
        "laptop": "laptopcomputer", "mortarboard-01": "graduationcap.fill",
        "notebook-01": "book.closed.fill", "translate": "character.book.closed.fill",
        "diploma": "graduationcap.fill", "computer": "desktopcomputer",
        // Finanzas
        "money-bag-02": "dollarsign.circle.fill", "chart-increase": "chart.line.uptrend.xyaxis",
        "building-02": "building.2.fill", "star": "star.fill", "exchange-01": "arrow.left.arrow.right",
        "credit-card": "creditcard.fill", "piggy-bank": "banknote.fill",
        "invoice-02": "doc.text.fill", "shield-01": "shield.fill", "bank": "building.columns.fill",
        "coins-01": "dollarsign.circle.fill",
        // Viajes / varios
        "hotel-02": "bed.double.fill", "luggage-01": "suitcase.fill", "compass": "safari.fill",
        "passport-01": "person.text.rectangle.fill", "gift": "gift.fill",
        "favourite": "heart.fill", "repeat": "repeat", "alert-02": "exclamationmark.triangle.fill",
        "more-horizontal": "ellipsis", "dashboard-square-01": "square.grid.2x2.fill",
    ]

    // Fallback por palabra clave (para nombres de categoría en español o slugs nuevos).
    private static let keywordTable: [(String, String)] = [
        ("aliment", "fork.knife"), ("comida", "fork.knife"), ("food", "fork.knife"),
        ("transport", "car.fill"), ("taxi", "car.fill"), ("gasolin", "fuelpump.fill"),
        ("vivienda", "house.fill"), ("hogar", "house.fill"), ("casa", "house.fill"),
        ("salud", "cross.fill"), ("medic", "pills.fill"), ("gym", "dumbbell.fill"),
        ("entreten", "tv.fill"), ("cine", "theatermasks.fill"), ("music", "music.note"),
        ("ropa", "tshirt.fill"), ("compra", "bag.fill"), ("shop", "bag.fill"),
        ("educ", "graduationcap.fill"), ("libro", "book.fill"),
        ("salario", "dollarsign.circle.fill"), ("sueldo", "dollarsign.circle.fill"),
        ("ahorro", "banknote.fill"), ("invers", "chart.line.uptrend.xyaxis"),
        ("viaje", "airplane"), ("regalo", "gift.fill"), ("mascota", "pawprint.fill"),
        ("servicio", "bolt.fill"), ("suscrip", "repeat"),
    ]
}
