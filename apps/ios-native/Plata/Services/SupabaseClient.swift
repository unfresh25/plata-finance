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

    // MARK: RPC

    @discardableResult
    func rpc<R: Decodable>(_ name: String, params: [String: Any] = [:]) async throws -> R {
        let url = SupabaseConfig.url.appendingPathComponent("/rest/v1/rpc/\(name)")
        let data = try JSONSerialization.data(withJSONObject: params)
        return try await requestRaw(url: url, method: "POST", body: data, single: true)
    }

    // MARK: - Bajo nivel

    private func request<T: Decodable>(path: String, method: String, body: Any?, authed: Bool) async throws -> T {
        let url = SupabaseConfig.url.appendingPathComponent(path)
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
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if authed, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if !authed {
            req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        } else if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Respuesta inválida del servidor.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "Error \(http.statusCode)"
            throw SupabaseError(message: msg)
        }

        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        if data.isEmpty { return EmptyResponse() as! T }
        return try decoder.decode(T.self, from: data)
    }
}

struct EmptyResponse: Decodable {}
