import Foundation

// Cliente del backend de banca (Syncfy). El backend guarda la api_key; la app
// solo maneja un token temporal de sesión. Mismo patrón de red que Chat/OCR:
// URLSession + Bearer del JWT de Supabase.

// MARK: - Modelos del catálogo / conexión

struct BankCountry: Decodable, Identifiable, Hashable {
    let id_country: String
    let name: String
    let code: String
    var id: String { id_country }

    /// Bandera emoji desde el código ISO (regional indicator symbols).
    var flag: String {
        let base: UInt32 = 0x1F1E6
        var s = ""
        for scalar in code.uppercased().unicodeScalars where scalar.value >= 65 && scalar.value <= 90 {
            if let u = Unicode.Scalar(base + scalar.value - 65) { s.unicodeScalars.append(u) }
        }
        return s.isEmpty ? "🏳️" : s
    }
}

/// Campo dinámico de credencial o de TWOFA que Syncfy define por site.
struct BankField: Decodable, Hashable {
    let name: String
    let type: String          // text | password | select | array | ...
    let label: String?
    let required: Bool?
    let options: [BankOption]?
}

struct BankOption: Decodable, Hashable {
    let label: String
    let value: String
}

struct BankSite: Decodable, Identifiable, Hashable {
    let id_site: String
    let id_site_organization: String?
    let name: String
    let endpoint: String?
    let credentials: [BankField]?
    var id: String { id_site }
    // El endpoint anidado a veces no viene; por defecto el estándar.
    var resolvedEndpoint: String { endpoint ?? "/v1/credentials/pulls" }
}

/// Institución (banco) agrupada, con logo y sus sites (Personas/Empresas).
struct BankOrganization: Decodable, Identifiable, Hashable {
    let id_site_organization: String
    let name: String
    let avatar: String?
    let sites: [BankSite]?
    var id: String { id_site_organization }
}

// Conexión y cuentas ya persistidas (desde nuestra BD).
struct BankConnection: Decodable, Identifiable, Hashable {
    let id: String
    let institution: String
    let status: String                 // active | requires_reauth | error | syncing
    let provider_credential_id: String
    let provider_site_id: String
    let last_successful_sync_at: String?
    let accounts: [BankAccountRow]?
}

struct BankAccountRow: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let number: String?
    let balance: Double
    let currency: String?
    let last_synced_at: String?

    /// Número enmascarado para mostrar (últimos 4). El número ya suele venir
    /// parcial; si trae dígitos, muestra •••• 1234.
    var maskedNumber: String? {
        guard let n = number, !n.isEmpty else { return nil }
        let digits = n.filter(\.isNumber)
        guard digits.count >= 4 else { return n }
        return "•••• " + String(digits.suffix(4))
    }
}

struct BankSession: Decodable { let token: String; let syncfy_user_id: String }
struct BankConnectResult: Decodable { let id_credential: String; let id_job: String; let connection_id: String }
struct BankJobStatus: Decodable { let code: Int?; let twofa: [BankField]? }

// MARK: - Servicio

enum BankService {
    private static func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        var bodyData: Data?
        if let body { bodyData = try JSONEncoder().encode(AnyEncodable(body)) }

        var (data, http) = try await send(path, method: method, body: bodyData)
        // JWT de Supabase expirado: refrescar una vez y reintentar (como SupabaseClient).
        if http.statusCode == 401, SupabaseClient.shared.accessToken != nil {
            if await SupabaseClient.shared.refreshSessionIfPossible() {
                (data, http) = try await send(path, method: method, body: bodyData)
            }
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
            throw SupabaseError(message: detail ?? "No se pudo contactar el servicio bancario.")
        }
        return data
    }

    private static func send(_ path: String, method: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        // path puede llevar query; se construye la URL a mano para no escapar el '?'.
        let base = SupabaseConfig.apiURL.absoluteString
        guard let url = URL(string: base + (base.hasSuffix("/") ? "" : "/") + path) else {
            throw SupabaseError(message: "URL inválida.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError(message: "Respuesta inválida del servidor.")
        }
        return (data, http)
    }

    /// Crea/reutiliza el usuario Syncfy y devuelve un token temporal.
    static func session() async throws -> BankSession {
        let data = try await request("bank/session", method: "POST", body: EmptyBody())
        return try JSONDecoder().decode(BankSession.self, from: data)
    }

    static func countries(token: String) async throws -> [BankCountry] {
        let data = try await request("bank/countries?token=\(token.urlEncoded)")
        return try JSONDecoder().decode(CountriesBody.self, from: data).countries
    }

    static func organizations(token: String, countryId: String) async throws -> [BankOrganization] {
        let path = "bank/organizations?token=\(token.urlEncoded)&id_country=\(countryId.urlEncoded)"
        let data = try await request(path)
        return try JSONDecoder().decode(OrgsBody.self, from: data).organizations
    }

    static func connect(token: String, site: BankSite, institution: String, credentials: [String: String]) async throws -> BankConnectResult {
        let body = ConnectBody(token: token, endpoint: site.resolvedEndpoint, id_site: site.id_site,
                               institution: institution, credentials: credentials)
        let data = try await request("bank/connect", method: "POST", body: body)
        return try JSONDecoder().decode(BankConnectResult.self, from: data)
    }

    static func jobStatus(token: String, idJob: String) async throws -> BankJobStatus {
        let data = try await request("bank/job?token=\(token.urlEncoded)&id_job=\(idJob.urlEncoded)")
        return try JSONDecoder().decode(BankJobStatus.self, from: data)
    }

    static func answerTwofa(token: String, idJob: String, answers: [String: String]) async throws {
        let body = TwofaBody(token: token, id_job: idJob, answers: answers)
        _ = try await request("bank/twofa", method: "POST", body: body)
    }

    /// Trae y persiste accounts + transactions de una credencial ya conectada.
    static func sync(token: String, idCredential: String) async throws {
        _ = try await request("bank/sync", method: "POST", body: SyncBody(token: token, id_credential: idCredential))
    }

    /// Conexiones + cuentas del hogar (desde nuestra BD).
    static func connections() async throws -> [BankConnection] {
        let data = try await request("bank/connections")
        return try JSONDecoder().decode(ConnectionsBody.self, from: data).connections
    }

    static func disconnect(token: String, idCredential: String) async throws {
        _ = try await request("bank/disconnect", method: "POST", body: SyncBody(token: token, id_credential: idCredential))
    }

    private struct SyncBody: Encodable { let token: String; let id_credential: String }
    private struct ConnectionsBody: Decodable { let connections: [BankConnection] }

    // Payloads
    private struct EmptyBody: Encodable {}
    private struct ConnectBody: Encodable {
        let token: String; let endpoint: String; let id_site: String
        let institution: String; let credentials: [String: String]
    }
    private struct TwofaBody: Encodable { let token: String; let id_job: String; let answers: [String: String] }
    private struct CountriesBody: Decodable { let countries: [BankCountry] }
    private struct OrgsBody: Decodable { let organizations: [BankOrganization] }
    private struct ErrorBody: Decodable { let detail: String? }
}

private extension String {
    var urlEncoded: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self }
}

/// Envuelve un Encodable para poder serializar bodies heterogéneos.
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}
