import SwiftUI

// Catálogo de logos de apps/suscripciones (namespace "Logos" en Assets).
// Cada slug corresponde a un imageset. Usar SubscriptionLogo.image(for:).
enum SubscriptionLogo {
    /// Todos los slugs disponibles como logo de suscripción.
    static let all: [String] = [
        "adobe-cloud",
        "amazon-music",
        "antigravity",
        "apidog",
        "apple-arcade",
        "apple-music",
        "appletv",
        "atlassian",
        "aws",
        "azure",
        "bolt",
        "calm",
        "canva",
        "claude",
        "cloudfare",
        "codex",
        "copilot",
        "coursera",
        "cursor",
        "discord",
        "disney-",
        "dribbble",
        "dropbox",
        "duolingo",
        "figma",
        "framer",
        "gemini",
        "github",
        "google-one",
        "google-play",
        "grammarly",
        "hbo-max",
        "headspace",
        "huggingface",
        "hulu",
        "icloud",
        "instagram",
        "kick",
        "linkedin",
        "lovable",
        "medium",
        "mercado-libre",
        "meta",
        "microsoft",
        "midjourney",
        "mistral",
        "n8n",
        "neon",
        "netflix",
        "nintendo-online",
        "nordvpn",
        "notion",
        "obsidian",
        "office-365",
        "ollama",
        "onedrive",
        "openai",
        "openrouter",
        "paramount-",
        "patreon",
        "perplexity",
        "planetscale",
        "platzi",
        "playstation-",
        "prime-video",
        "rappi",
        "resend",
        "roblox",
        "shopify",
        "slack",
        "soundcloud",
        "spotify",
        "strava",
        "supabase",
        "telegram",
        "the-economist",
        "the-new-york-times",
        "threads",
        "tidal",
        "tiktok",
        "todoist",
        "trello",
        "twitch",
        "uber",
        "udemy",
        "unity",
        "v0",
        "vercel",
        "webflow",
        "whatsapp",
        "windsurf",
        "x",
        "xbox",
        "youtube",
        "youtube-music",
        "zoom",
    ]

    /// Devuelve la imagen del logo si existe en el catálogo.
    static func image(for slug: String?) -> Image? {
        guard let slug, all.contains(slug) else { return nil }
        return Image("Logos/\(slug)")
    }

    /// Resuelve el slug real del catálogo para un `logo_id` guardado en la BD.
    /// Los ids de la BD (heredados del picker original) no siempre coinciden con
    /// los slugs del asset catalog — p.ej. "disney" en la BD es "disney-" aquí,
    /// porque el nombre de archivo original era "Disney+.png".
    static func slug(forStoredId id: String?) -> String? {
        guard let id, !id.isEmpty else { return nil }
        if all.contains(id) { return id }                 // coincidencia directa
        if all.contains(id + "-") { return id + "-" }     // disney → disney-
        // Prefijo: el slug más largo cuya base coincida con el id.
        return all.first { $0.hasPrefix(id) }
    }

    /// Imagen a partir del `logo_id` almacenado (con la normalización anterior).
    static func imageForStoredId(_ id: String?) -> Image? {
        image(for: slug(forStoredId: id))
    }
}
