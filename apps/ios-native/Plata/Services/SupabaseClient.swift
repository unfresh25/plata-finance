import Foundation

// Cliente Supabase ligero sobre URLSession — sin dependencias externas.
// Cubre auth (GoTrue), datos (PostgREST) y RPC. La seguridad real la da RLS;
// aquí solo se usa la anon key y el JWT del usuario.

enum SupabaseConfig {
    // Mismo proyecto que la app actual y el backend de Render.
    static let url = URL(string: "https://ibqxrxouwoukqmzartso.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlicXhyeG91d291a3FtemFydHNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyNDIxMjksImV4cCI6MjA4OTgxODEyOX0.V2T4fUltQNNzOblXn6xSCuWWm1EFUH1d6gBuRkgB3eo"
    // Backend FastAPI (OCR de recibos).
    static let apiURL = URL(string: "https://plata-finance-api.onrender.com")!
}

// MARK: - Errores

struct SupabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Sesión

struct Session: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String?
}

// MARK: - Cliente

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let session = URLSession(configuration: .default)
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let encoder = JSONEncoder()

    /// Token de acceso actual (se guarda en Keychain vía TokenStore).
    var accessToken: String?

    private init() {
        accessToken = TokenStore.load()?.accessToken
    }

    // MARK: Auth

    func signIn(email: String, password: String) async throws -> Session {
        let body = ["email": email, "password": password]
        let session: Session = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: body,
            authed: false
        )
        persist(session)
        return session
    }

    func signUp(email: String, password: String, name: String) async throws -> Session {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["name": name],
        ]
        let session: Session = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            body: body,
            authed: false
        )
        persist(session)
        return session
    }

    func signOut() {
        accessToken = nil
        TokenStore.clear()
    }

    /// Refresca la sesión con el refresh_token guardado. Devuelve true si se
    /// renovó (y persiste la nueva sesión). Se coalescen las llamadas concurrentes
    /// para no refrescar varias veces a la vez cuando caducan muchas requests.
    private var refreshTask: Task<Bool, Never>?

    @discardableResult
    func refreshSessionIfPossible() async -> Bool {
        if let existing = refreshTask { return await existing.value }
        let task = Task { () -> Bool in
            defer { refreshTask = nil }
            guard let refreshToken = TokenStore.load()?.refreshToken else { return false }
            do {
                let session: Session = try await request(
                    path: "/auth/v1/token?grant_type=refresh_token",
                    method: "POST",
                    body: ["refresh_token": refreshToken],
                    authed: false
                )
                persist(session)
                return true
            } catch {
                return false
            }
        }
        refreshTask = task
        return await task.value
    }

    private func persist(_ session: Session) {
        accessToken = session.accessToken
        TokenStore.save(session)
    }

    // MARK: REST (PostgREST)

    /// SELECT genérico. `query` son los parámetros de PostgREST (select, filtros…).
    func from<T: Decodable>(_ table: String, query: [String: String] = [:]) async throws -> [T] {
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("/rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await requestRaw(url: comps.url!, method: "GET", body: nil)
    }

    @discardableResult
    func insert<T: Encodable, R: Decodable>(_ table: String, values: T) async throws -> [R] {
        let url = SupabaseConfig.url.appendingPathComponent("/rest/v1/\(table)")
        return try await requestRaw(url: url, method: "POST", body: try encoder.encode(values), prefer: "return=representation")
    }

    func update<T: Encodable>(_ table: String, values: T, match: [String: String]) async throws {
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("/rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        let _: EmptyResponse = try await requestRaw(url: comps.url!, method: "PATCH", body: try encoder.encode(values), single: true)
    }

    func delete(_ table: String, match: [String: String]) async throws {
        var comps = URLComponents(url: SupabaseConfig.url.appendingPathComponent("/rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = match.map { URLQueryItem(name: $0.key, value: "eq.\($0.value)") }
        let _: EmptyResponse = try await requestRaw(url: comps.url!, method: "DELETE", body: nil, single: true)
    }

    // MARK: Storage

    /// Sube bytes al bucket de Storage y devuelve la URL pública (con cache-buster).
    /// Usado para el avatar del perfil (bucket "avatars", RLS: owner-only).
    func uploadToStorage(bucket: String, path: String, data: Data, contentType: String) async throws -> String {
        let url = SupabaseConfig.url.appendingPathComponent("/storage/v1/object/\(bucket)/\(path)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "x-upsert")   // sobrescribe si existe
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = data

        let (respData, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: respData, encoding: .utf8) ?? "Error al subir la imagen."
            throw SupabaseError(message: msg)
        }
        // URL pública (el bucket avatars es de lectura pública) + cache-buster.
        let publicURL = SupabaseConfig.url.appendingPathComponent("/storage/v1/object/public/\(bucket)/\(path)")
        return "\(publicURL.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
    }

    // MARK: RPC

    @discardableResult
    func rpc<R: Decodable>(_ name: String, params: [String: Any] = [:]) async throws -> R {
        let url = SupabaseConfig.url.appendingPathComponent("/rest/v1/rpc/\(name)")
        let data = try JSONSerialization.data(withJSONObject: params)
        return try await requestRaw(url: url, method: "POST", body: data, single: true)
    }

    // MARK: - Bajo nivel

    private func request<T: Decodable>(path: String, method: String, body: Any?, authed: Bool) async throws -> T {
        // Construir con string directo: appendingPathComponent ESCAPA el '?' del
        // query (lo vuelve %3F → 404). Concatenar sobre la URL base lo respeta.
        guard let url = URL(string: SupabaseConfig.url.absoluteString + path) else {
            throw SupabaseError(message: "URL inválida.")
        }
        let data = body.map { try? JSONSerialization.data(withJSONObject: $0) } ?? nil
        return try await requestRaw(url: url, method: method, body: data, authed: authed, single: true)
    }

    private func requestRaw<T: Decodable>(
        url: URL,
        method: String,
        body: Data?,
        authed: Bool = true,
        prefer: String? = nil,
        single: Bool = false
    ) async throws -> T {
        let (data, http) = try await send(url: url, method: method, body: body, authed: authed, prefer: prefer)

        // Sesión caducada: intentar refrescar UNA vez con el refresh_token y
        // reintentar la request original. Solo aplica a peticiones autenticadas.
        if http.statusCode == 401, authed, accessToken != nil {
            if await refreshSessionIfPossible() {
                let (retryData, retryHTTP) = try await send(url: url, method: method, body: body, authed: authed, prefer: prefer)
                return try decode(retryData, status: retryHTTP.statusCode)
            }
            // No se pudo refrescar: sesión realmente inválida.
            throw SessionExpiredError()
        }

        return try decode(data, status: http.statusCode)
    }

    /// Ejecuta una request y devuelve datos + respuesta HTTP (sin interpretar el status).
    private func send(
        url: URL, method: String, body: Data?, authed: Bool, prefer: String?
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if authed, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Respuesta inválida del servidor.")
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ data: Data, status: Int) throws -> T {
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "Error \(status)"
            throw SupabaseError(message: msg)
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        if data.isEmpty { return EmptyResponse() as! T }
        return try decoder.decode(T.self, from: data)
    }
}

/// La sesión caducó y no se pudo refrescar: el usuario debe volver a entrar.
/// Se distingue de otros errores para mostrar un mensaje limpio (no el JSON crudo).
struct SessionExpiredError: LocalizedError {
    var errorDescription: String? { "Tu sesión expiró. Vuelve a iniciar sesión." }
}

struct EmptyResponse: Decodable {}
