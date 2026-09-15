import SwiftUI

/// Avatar del usuario: muestra la foto de perfil (avatar_url) si existe, con
/// AsyncImage; si no, la inicial del nombre sobre un fondo de acento. Reutilizado
/// en el header del dashboard y en Ajustes.
struct AvatarView: View {
    var name: String?
    var urlString: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialFallback
                    }
                }
            } else {
                initialFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // Hairline luminoso del acento: define el avatar sin glow.
        .overlay(Circle().strokeBorder(Palette.accent.opacity(0.22), lineWidth: 0.5))
    }

    private var initialFallback: some View {
        Circle()
            .fill(Palette.accent.opacity(0.16))
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.accent)
            )
    }

    private var initial: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespaces)
        return String(trimmed.first ?? "?").uppercased()
    }
}
