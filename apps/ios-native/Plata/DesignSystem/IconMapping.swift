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

    // Mapeo directo de los slugs conocidos: los del IconDictionary original de
    // Hugeicons (picker) más los slugs cortos legacy que siembra la BD
    // (restaurant, car, home, heart, tv, shirt, book, money, chart…).
    private static let table: [String: String] = [
        // ── Comida y bebida ──────────────────────────────────────────────
        "hamburger-01": "fork.knife", "coffee-01": "cup.and.saucer.fill",
        "natural-food": "carrot.fill", "pizza-01": "fork.knife.circle.fill",
        "drink": "wineglass.fill", "croissant": "birthday.cake.fill",
        "candy": "birthday.cake.fill",
        "restaurant": "fork.knife", "food": "fork.knife", "cafe": "cup.and.saucer.fill",
        "coffee": "cup.and.saucer.fill", "grocery": "cart.fill", "groceries": "cart.fill",
        "supermarket": "cart.fill", "beer": "wineglass.fill", "wine": "wineglass.fill",
        // ── Transporte ───────────────────────────────────────────────────
        "taxi": "car.fill", "fuel-station": "fuelpump.fill", "bus-01": "bus.fill",
        "airplane-01": "airplane", "car-01": "car.fill", "motorbike-02": "scooter",
        "bicycle": "bicycle", "parking-meter": "parkingsign",
        "car": "car.fill", "bus": "bus.fill", "train": "tram.fill", "metro": "tram.fill",
        "fuel": "fuelpump.fill", "gas": "fuelpump.fill", "gasoline": "fuelpump.fill",
        "plane": "airplane", "motorbike": "scooter", "bike": "bicycle",
        "parking": "parkingsign",
        // ── Hogar / servicios ────────────────────────────────────────────
        "home-01": "house.fill", "invoice-01": "doc.text.fill", "wifi-02": "wifi",
        "wrench-01": "wrench.and.screwdriver.fill", "sofa-01": "sofa.fill",
        "washing-machine": "washer.fill", "paint-brush-02": "paintbrush.fill",
        "home": "house.fill", "house": "house.fill", "rent": "house.fill",
        "invoice": "doc.text.fill", "bill": "doc.text.fill", "wifi": "wifi",
        "internet": "wifi", "electricity": "bolt.fill", "water": "drop.fill",
        "utilities": "bolt.fill", "wrench": "wrench.and.screwdriver.fill",
        "tools": "wrench.and.screwdriver.fill", "furniture": "sofa.fill",
        "cleaning": "sparkles",
        // ── Salud y bienestar ────────────────────────────────────────────
        "hospital-01": "cross.fill", "medicine-02": "pills.fill",
        "dumbbell-01": "dumbbell.fill", "mentoring": "brain.head.profile",
        "dental-tooth": "cross.case.fill", "glasses": "eyeglasses",
        "first-aid-kit": "cross.case.fill",
        "hospital": "cross.fill", "health": "heart.fill", "heart": "heart.fill",
        "medicine": "pills.fill", "pharmacy": "cross.case.fill", "doctor": "stethoscope",
        "gym": "dumbbell.fill", "fitness": "dumbbell.fill", "dental": "cross.case.fill",
        "therapy": "brain.head.profile",
        // ── Entretenimiento ──────────────────────────────────────────────
        "tv-01": "tv.fill", "game-controller-01": "gamecontroller.fill",
        "theater": "theatermasks.fill", "music-note-01": "music.note",
        "book-01": "book.fill", "volleyball": "volleyball.fill", "ticket-01": "ticket.fill",
        "tv": "tv.fill", "streaming": "play.tv.fill", "netflix": "play.tv.fill",
        "game": "gamecontroller.fill", "games": "gamecontroller.fill",
        "gaming": "gamecontroller.fill", "cinema": "theatermasks.fill",
        "movie": "film.fill", "movies": "film.fill", "music": "music.note",
        "book": "book.fill", "books": "book.fill", "sports": "volleyball.fill",
        "ticket": "ticket.fill", "concert": "ticket.fill", "party": "party.popper.fill",
        // ── Compras y ropa ───────────────────────────────────────────────
        "t-shirt": "tshirt.fill", "running-shoes": "shoe.fill", "watch-01": "applewatch",
        "smartphone-01": "iphone", "smart-phone-01": "iphone", "hair-dryer": "wind",
        "bird": "pawprint.fill", "baby-01": "figure.and.child.holdinghands",
        "shirt": "tshirt.fill", "clothes": "tshirt.fill", "clothing": "tshirt.fill",
        "shoes": "shoe.fill", "watch": "applewatch", "accessories": "applewatch",
        "phone": "iphone", "smartphone": "iphone", "tech": "laptopcomputer",
        "technology": "laptopcomputer", "electronics": "laptopcomputer",
        "gadgets": "iphone", "beauty": "sparkles", "cosmetics": "sparkles",
        "pet": "pawprint.fill", "pets": "pawprint.fill", "dog": "pawprint.fill",
        "cat": "pawprint.fill", "baby": "figure.and.child.holdinghands",
        "toys": "teddybear.fill", "shopping": "bag.fill", "shop": "bag.fill",
        "store": "bag.fill",
        // ── Educación / trabajo ──────────────────────────────────────────
        "laptop": "laptopcomputer", "mortarboard-01": "graduationcap.fill",
        "notebook-01": "book.closed.fill", "translate": "character.book.closed.fill",
        "diploma": "graduationcap.fill", "computer": "desktopcomputer",
        "education": "graduationcap.fill", "school": "graduationcap.fill",
        "university": "graduationcap.fill", "college": "graduationcap.fill",
        "course": "laptopcomputer", "courses": "laptopcomputer",
        "study": "book.closed.fill", "language": "character.book.closed.fill",
        "work": "briefcase.fill", "office": "briefcase.fill",
        "freelance": "desktopcomputer", "business": "briefcase.fill",
        // ── Ingresos / finanzas ──────────────────────────────────────────
        "money-bag-02": "dollarsign.circle.fill", "chart-increase": "chart.line.uptrend.xyaxis",
        "building-02": "building.2.fill", "star": "star.fill", "exchange-01": "arrow.left.arrow.right",
        "credit-card": "creditcard.fill", "piggy-bank": "banknote.fill",
        "invoice-02": "doc.text.fill", "shield-01": "shield.fill", "bank": "building.columns.fill",
        "coins-01": "dollarsign.circle.fill",
        "money": "dollarsign.circle.fill", "salary": "dollarsign.circle.fill",
        "wage": "dollarsign.circle.fill", "income": "dollarsign.circle.fill",
        "cash": "banknote.fill", "chart": "chart.line.uptrend.xyaxis",
        "investment": "chart.line.uptrend.xyaxis", "investments": "chart.line.uptrend.xyaxis",
        "stocks": "chart.line.uptrend.xyaxis", "bonus": "star.fill",
        "refund": "arrow.left.arrow.right", "transfer": "arrow.left.arrow.right",
        "exchange": "arrow.left.arrow.right", "creditcard": "creditcard.fill",
        "card": "creditcard.fill", "debt": "creditcard.fill", "loan": "creditcard.fill",
        "credit": "creditcard.fill", "savings": "banknote.fill", "saving": "banknote.fill",
        "tax": "doc.text.fill", "taxes": "doc.text.fill", "insurance": "shield.fill",
        "cashback": "dollarsign.circle.fill", "fee": "building.columns.fill",
        "fees": "building.columns.fill",
        // ── Viajes ───────────────────────────────────────────────────────
        "hotel-02": "bed.double.fill", "luggage-01": "suitcase.fill", "compass": "safari.fill",
        "passport-01": "person.text.rectangle.fill",
        "hotel": "bed.double.fill", "travel": "airplane", "trip": "airplane",
        "flight": "airplane", "flights": "airplane", "luggage": "suitcase.fill",
        "vacation": "beach.umbrella.fill", "tour": "safari.fill", "tours": "safari.fill",
        "passport": "person.text.rectangle.fill", "visa": "person.text.rectangle.fill",
        // ── Varios ───────────────────────────────────────────────────────
        "gift": "gift.fill", "favourite": "heart.fill", "favorite": "heart.fill",
        "repeat": "repeat", "subscription": "repeat", "subscriptions": "repeat",
        "alert-02": "exclamationmark.triangle.fill", "fine": "exclamationmark.triangle.fill",
        "fines": "exclamationmark.triangle.fill", "penalty": "exclamationmark.triangle.fill",
        "donation": "heart.fill", "charity": "heart.fill",
        "more-horizontal": "ellipsis", "other": "ellipsis",
        "others": "ellipsis", "dashboard-square-01": "square.grid.2x2.fill",
    ]

    // Fallback por palabra clave (para nombres de categoría en español o slugs
    // nuevos no listados arriba). Se recorre en orden; el primero contenido gana.
    private static let keywordTable: [(String, String)] = [
        // Comida
        ("aliment", "fork.knife"), ("comida", "fork.knife"), ("food", "fork.knife"),
        ("restaur", "fork.knife"), ("mercado", "cart.fill"), ("super", "cart.fill"),
        ("grocer", "cart.fill"), ("café", "cup.and.saucer.fill"), ("cafe", "cup.and.saucer.fill"),
        ("coffee", "cup.and.saucer.fill"), ("bebida", "wineglass.fill"),
        ("domicil", "fork.knife.circle.fill"), ("pan", "birthday.cake.fill"),
        ("snack", "birthday.cake.fill"), ("dulce", "birthday.cake.fill"),
        // Transporte
        ("transport", "car.fill"), ("taxi", "car.fill"), ("uber", "car.fill"),
        ("carro", "car.fill"), ("auto", "car.fill"), ("gasolin", "fuelpump.fill"),
        ("combustib", "fuelpump.fill"), ("gas", "fuelpump.fill"), ("fuel", "fuelpump.fill"),
        ("bus", "bus.fill"), ("metro", "tram.fill"), ("tren", "tram.fill"),
        ("vuelo", "airplane"), ("moto", "scooter"), ("bici", "bicycle"),
        ("parqueo", "parkingsign"), ("estacion", "parkingsign"),
        // Hogar / servicios
        ("vivienda", "house.fill"), ("hogar", "house.fill"), ("casa", "house.fill"),
        ("arriendo", "house.fill"), ("renta", "house.fill"), ("alquiler", "house.fill"),
        ("internet", "wifi"), ("wifi", "wifi"), ("luz", "bolt.fill"),
        ("agua", "drop.fill"), ("factura", "doc.text.fill"), ("reparac", "wrench.and.screwdriver.fill"),
        ("mueble", "sofa.fill"), ("electrodom", "washer.fill"), ("decorac", "paintbrush.fill"),
        ("limpieza", "sparkles"),
        // Salud
        ("salud", "heart.fill"), ("médic", "cross.fill"), ("medic", "pills.fill"),
        ("clínic", "cross.fill"), ("clinic", "cross.fill"), ("farmac", "cross.case.fill"),
        ("gym", "dumbbell.fill"), ("gimnas", "dumbbell.fill"), ("fitness", "dumbbell.fill"),
        ("dental", "cross.case.fill"), ("odontolog", "cross.case.fill"),
        ("óptic", "eyeglasses"), ("optic", "eyeglasses"), ("psicolog", "brain.head.profile"),
        ("terapia", "brain.head.profile"),
        // Entretenimiento
        ("entreten", "tv.fill"), ("streaming", "play.tv.fill"), ("cine", "theatermasks.fill"),
        ("película", "film.fill"), ("pelicula", "film.fill"), ("music", "music.note"),
        ("músic", "music.note"), ("juego", "gamecontroller.fill"), ("game", "gamecontroller.fill"),
        ("deporte", "volleyball.fill"), ("concierto", "ticket.fill"), ("evento", "ticket.fill"),
        ("fiesta", "party.popper.fill"),
        // Ropa / compras
        ("ropa", "tshirt.fill"), ("zapato", "shoe.fill"), ("calzado", "shoe.fill"),
        ("accesorio", "applewatch"), ("tecnolog", "laptopcomputer"), ("gadget", "iphone"),
        ("celular", "iphone"), ("teléfono", "iphone"), ("telefono", "iphone"),
        ("belleza", "sparkles"), ("cuidado", "sparkles"),
        ("juguete", "teddybear.fill"), ("bebé", "figure.and.child.holdinghands"),
        ("bebe", "figure.and.child.holdinghands"),
        ("compra", "bag.fill"), ("shop", "bag.fill"), ("tienda", "bag.fill"),
        // Educación / trabajo
        ("educ", "graduationcap.fill"), ("universidad", "graduationcap.fill"),
        ("colegio", "graduationcap.fill"), ("escuela", "graduationcap.fill"),
        ("curso", "laptopcomputer"), ("idioma", "character.book.closed.fill"),
        ("libro", "book.fill"), ("estudio", "book.closed.fill"),
        ("trabajo", "briefcase.fill"), ("freelance", "desktopcomputer"),
        ("negocio", "briefcase.fill"), ("oficina", "briefcase.fill"),
        // Ingresos / finanzas
        ("salario", "dollarsign.circle.fill"), ("sueldo", "dollarsign.circle.fill"),
        ("ingreso", "dollarsign.circle.fill"), ("nómina", "dollarsign.circle.fill"),
        ("nomina", "dollarsign.circle.fill"), ("bono", "star.fill"),
        ("comisión", "star.fill"), ("comision", "star.fill"), ("reembolso", "arrow.left.arrow.right"),
        ("ahorro", "banknote.fill"), ("invers", "chart.line.uptrend.xyaxis"),
        ("acción", "chart.line.uptrend.xyaxis"), ("transfer", "arrow.left.arrow.right"),
        ("tarjeta", "creditcard.fill"), ("crédit", "creditcard.fill"), ("credit", "creditcard.fill"),
        ("deuda", "creditcard.fill"), ("préstamo", "creditcard.fill"), ("prestamo", "creditcard.fill"),
        ("impuesto", "doc.text.fill"), ("seguro", "shield.fill"), ("banc", "building.columns.fill"),
        ("cashback", "dollarsign.circle.fill"), ("dinero", "dollarsign.circle.fill"),
        // Viajes
        ("hotel", "bed.double.fill"), ("viaje", "airplane"),
        ("maleta", "suitcase.fill"), ("vacacion", "beach.umbrella.fill"),
        ("tour", "safari.fill"), ("visa", "person.text.rectangle.fill"),
        ("pasaporte", "person.text.rectangle.fill"),
        // Varios
        ("regalo", "gift.fill"), ("gift", "gift.fill"), ("donac", "heart.fill"),
        ("caridad", "heart.fill"), ("mascota", "pawprint.fill"), ("pet", "pawprint.fill"),
        ("servicio", "bolt.fill"), ("suscrip", "repeat"), ("subscri", "repeat"),
        ("multa", "exclamationmark.triangle.fill"), ("penal", "exclamationmark.triangle.fill"),
        ("otro", "ellipsis"),
    ]
}
