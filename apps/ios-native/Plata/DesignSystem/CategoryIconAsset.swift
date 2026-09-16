import SwiftUI
import UIKit

// Íconos de categoría REALES de Hugeicons (los mismos del picker legacy),
// empaquetados como SVG teñibles en Assets.xcassets/CategoryIcons. La BD guarda
// el slug del ícono (ej. "hamburger-01", "taxi", "gift"); aquí se resuelve al
// asset correspondiente y se devuelve como Image template (respeta el color de
// la categoría vía .foregroundStyle). Si el slug no tiene asset, devuelve nil y
// el caller cae al SF Symbol de IconMapping.

enum CategoryIconAsset {
    /// Namespace del asset catalog donde viven los SVG de Hugeicons.
    private static let namespace = "CategoryIcons/"

    /// Devuelve el Image de Hugeicons para el slug guardado en la BD, o nil si no
    /// existe ese asset. El slug se normaliza (minúsculas, sin espacios).
    static func image(forSlug slug: String?) -> Image? {
        guard let key = normalize(slug), !key.isEmpty else { return nil }
        let assetName = namespace + key
        guard UIImage(named: assetName) != nil else { return nil }
        return Image(assetName).renderingMode(.template)
    }

    /// ¿Existe un Hugeicon para este slug? (para decidir logo vs SF Symbol).
    static func has(_ slug: String?) -> Bool {
        guard let key = normalize(slug), !key.isEmpty else { return false }
        return UIImage(named: namespace + key) != nil
    }

    private static func normalize(_ slug: String?) -> String? {
        slug?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
