import Foundation
import Security

indirect enum JSONValue: Codable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let x): try c.encode(x)
        case .array(let x): try c.encode(x)
        case .string(let x): try c.encode(x)
        case .number(let x): try c.encode(x)
        case .bool(let x): try c.encode(x)
        case .null: try c.encodeNil()
        }
    }
    subscript(_ key: String) -> JSONValue { if case .object(let x) = self { x[key] ?? .null } else { .null } }
    var array: [JSONValue] { if case .array(let x) = self { x } else { [] } }
    var string: String { switch self { case .string(let x): x; case .number(let x): String(format: "%.0f", x); default: "" } }
    var numericValue: Double? {
        let value: Double?
        switch self { case .number(let x): value = x; case .string(let x): value = Double(x); default: value = nil }
        guard let value, value.isFinite else { return nil }
        return value
    }
    var number: Double { numericValue ?? 0 }
    var int: Int {
        let value = number
        if value >= Double(Int.max) { return Int.max }
        if value <= Double(Int.min) { return Int.min }
        return Int(value)
    }
    func hasKey(_ key: String) -> Bool { if case .object(let object) = self { object[key] != nil } else { false } }
    var isArray: Bool { if case .array = self { true } else { false } }
    var bool: Bool { if case .bool(let x) = self { x } else { false } }
    var exists: Bool { if case .null = self { false } else { true } }
}

enum APIError: LocalizedError {
    case unauthorized
    case server(String)
    case malformedResponse
    case keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .unauthorized: "登录已过期，请重新登录。"
        case .server(let message): message
        case .malformedResponse: "服务器返回了无法识别的数据，请稍后重试。"
        case .keychain: "无法安全保存登录信息，请重试。"
        }
    }
}

struct APIClient: Sendable {
    static let origin = URL(string: "https://www.krill-code.com")!
    private let session: URLSession
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }
    func request(_ path: String, token: String? = nil, body: [String: JSONValue]? = nil) async throws -> JSONValue {
        var request = URLRequest(url: Self.origin.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN", forHTTPHeaderField: "X-Language")
        request.setValue("zh-CN", forHTTPHeaderField: "Accept-Language")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(JSONValue.object(body)) }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.malformedResponse }
        let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        if response.statusCode == 401, token != nil { throw APIError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let message = json?["message"].string ?? ""
            let nested = json?["error"]["message"].string ?? ""
            let fallback = response.statusCode == 401 ? "邮箱、密码或验证码不正确，请重试。" : "请求失败（HTTP \(response.statusCode)），请稍后重试。"
            throw APIError.server(!message.isEmpty ? message : !nested.isEmpty ? nested : fallback)
        }
        guard let json, json.hasKey("data") else { throw APIError.malformedResponse }
        if json["success"].exists && !json["success"].bool {
            throw APIError.server(json["message"].string.isEmpty ? "请求未成功，请稍后重试。" : json["message"].string)
        }
        return json["data"]
    }
}

enum TokenVault {
    private static let service = "com.krill.app.session"
    private static let account = "krill-jwt"
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw APIError.keychain(added) }
        } else if update != errSecSuccess { throw APIError.keychain(update) }
    }
    static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}
