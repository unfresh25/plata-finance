import Foundation

// Cache de LECTURA en disco: persiste las colecciones tras cada refresh para que
// al abrir sin señal se vea el último estado conocido en vez de pantalla vacía.
// No es sync bidireccional; es "última foto buena". La escritura offline la maneja
// OfflineQueue por separado.

enum OfflineCache {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("plata-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func save<T: Encodable>(_ value: T, as name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: dir.appendingPathComponent("\(name).json"))
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("\(name).json")) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: dir)
    }
}
