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
    let endpoint: String
    let credentials: [BankField]?
    var id: String { id_site }
}

struct BankSession: Decodable { let token: String; let syncfy_user_id: String }
struct BankConnectResult: Decodable { let id_credential: String; let id_job: String; let connection_id: String }
struct BankJobStatus: Decodable { let code: Int?; let twofa: [BankField]? }

// MARK: - Servicio

enum BankService {
    private static func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        let url = SupabaseConfig.apiURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(SupabaseClient.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        if let body { req.httpBody = try JSONEncoder().encode(AnyEncodable(body)) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
            throw SupabaseError(message: detail ?? "No se pudo contactar el servicio bancario.")
        }
        return data
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

    static func sites(token: String, countryId: String, isTest: Bool) async throws -> [BankSite] {
        var path = "bank/sites?token=\(token.urlEncoded)&id_country=\(countryId.urlEncoded)"
        if isTest { path += "&is_test=true" }
        let data = try await request(path)
        return try JSONDecoder().decode(SitesBody.self, from: data).sites
    }

    static func connect(token: String, site: BankSite, credentials: [String: String]) async throws -> BankConnectResult {
        let body = ConnectBody(token: token, endpoint: site.endpoint, id_site: site.id_site,
                               institution: site.name, credentials: credentials)
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

    private struct SyncBody: Encodable { let token: String; let id_credential: String }

    // Payloads
    private struct EmptyBody: Encodable {}
    private struct ConnectBody: Encodable {
        let token: String; let endpoint: String; let id_site: String
        let institution: String; let credentials: [String: String]
    }
    private struct TwofaBody: Encodable { let token: String; let id_job: String; let answers: [String: String] }
    private struct CountriesBody: Decodable { let countries: [BankCountry] }
    private struct SitesBody: Decodable { let sites: [BankSite] }
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
