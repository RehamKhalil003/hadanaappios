import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    // ⚠️ للتيست على جهاز حقيقي: غيّر لـ IP الماك مثل "http://192.168.1.x:8000/api"
    private let baseURL = "https://carnation-suitcase-bulgur.ngrok-free.dev/api"
    private let tokenKey = "auth_token"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
    }

    var isAuthenticated: Bool { token != nil }

    // MARK: - Generic Request

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        print("🌐 REQUEST: \(method) \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        print("📥 STATUS: \(http.statusCode) | \(String(data: data, encoding: .utf8) ?? "no body")")

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            token = nil
            throw APIError.unauthorized
        case 403:
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String } ?? "غير مصرح"
            throw APIError.serverError(msg)
        case 422:
            // Validation errors — نأخذ أول رسالة من errors أو message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errors = json["errors"] as? [String: [String]],
                   let first = errors.values.first?.first {
                    throw APIError.serverError(first)
                }
                if let msg = json["message"] as? String {
                    throw APIError.serverError(msg)
                }
            }
            throw APIError.serverError("خطأ في البيانات المدخلة / Validation error")
        default:
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String } ?? "خطأ في الخادم"
            throw APIError.serverError(msg)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Auth Endpoints

    func login(phone: String, password: String) async throws -> LoginResponse {
        let response: LoginResponse = try await request(
            path: "/auth/login",
            method: "POST",
            body: ["phone": phone, "password": password]
        )
        token = response.token
        return response
    }

    func me() async throws -> MeResponse {
        return try await request(path: "/auth/me")
    }

    func logout() async throws {
        let _: EmptyResponse = try await request(path: "/auth/logout", method: "POST")
        token = nil
    }

    func updateFCMToken(_ fcmToken: String) async throws {
        let _: EmptyResponse = try await request(path: "/auth/fcm-token", method: "POST", body: ["fcm_token": fcmToken])
    }

    func removeFCMToken() async throws {
        let _: EmptyResponse = try await request(path: "/auth/fcm-token", method: "DELETE")
    }

    // MARK: - Parent Endpoints

    func children() async throws -> ChildrenResponse {
        return try await request(path: "/parent/children")
    }

    func fetchSessions(childId: Int) async throws -> SessionsResponse {
        return try await request(path: "/parent/children/\(childId)/sessions")
    }

    // MARK: - Contact

    func sendContactMessage(subject: String, message: String) async throws -> MessageSentResponse {
        return try await request(path: "/parent/contact", method: "POST",
                                 body: ["subject": subject, "message": message])
    }

    // MARK: - Notifications

    func fetchNotifications() async throws -> NotificationsResponse {
        return try await request(path: "/notifications")
    }

    func markNotificationRead(id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/notifications/\(id)/read", method: "POST")
    }

    func markAllNotificationsRead() async throws {
        let _: EmptyResponse = try await request(path: "/notifications/read-all", method: "POST")
    }

    func uploadCarPhoto(_ imageData: Data) async throws -> CarPhotoResponse {
        guard let url = URL(string: baseURL + "/parent/profile/car-photo") else { throw APIError.invalidURL }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = UserDefaults.standard.string(forKey: "access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"car.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(CarPhotoResponse.self, from: data)
    }

    func deleteCarPhoto() async throws {
        let _: EmptyResponse = try await request(path: "/parent/profile/car-photo", method: "DELETE")
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL, unauthorized, forbidden, unknown
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "رابط غير صحيح"
        case .unauthorized:        return "رقم الهاتف أو كلمة المرور غلط"
        case .forbidden:           return "غير مصرح لك بالدخول"
        case .serverError(let m):  return m
        case .unknown:             return "خطأ غير معروف"
        }
    }
}

// MARK: - Response Structs (Codable — match API exactly)

struct LoginResponse: Decodable {
    let token: String
    let user: MeResponse
}

struct MeResponse: Decodable {
    let id: Int
    let name: String
    let phone: String
    let role: String
    let carPhoto: String?

    enum CodingKeys: String, CodingKey {
        case id, name, phone, role
        case carPhoto = "car_photo"
    }
}

struct ChildrenResponse: Decodable {
    let data: [ChildAPIModel]
}

struct ToiletReminderAPIModel: Decodable {
    let is_active: Bool
    let interval_minutes: Int
    let start_time: String
    let end_time: String
}

struct ChildAPIModel: Decodable {
    let id: Int
    let name: String
    let nursery_only: Bool
    let specialists: [SpecialistAPIModel]
    let arrival_time: String?
    let departure_time: String?
    let toilet_reminder: ToiletReminderAPIModel?
}

struct SpecialistAPIModel: Decodable {
    let id: Int
    let name: String
    let specialization: String?
}

struct EmptyResponse: Decodable {}

struct CarPhotoResponse: Decodable {
    let message: String
    let carPhotoUrl: String?
    enum CodingKeys: String, CodingKey {
        case message
        case carPhotoUrl = "car_photo_url"
    }
}

struct MessageSentResponse: Decodable { let message: String }

struct SessionsResponse: Decodable {
    let data: [SessionAPIModel]
}

struct SessionAPIModel: Decodable, Equatable, Identifiable {
    let id: Int
    let session_date: String
    let session_time: String
    let session_time_to: String?
    let status: String
    let started_at: String?
    let ended_at: String?
    let remaining_minutes: Int?
    let goal: String?
    let specialization: String?
    let specialist: SessionSpecialistModel
    let notes: [SessionNoteAPIModel]
    let media: [SessionMediaAPIModel]
}

struct SessionSpecialistModel: Decodable, Equatable {
    let id: Int
    let name: String
}

struct SessionNoteAPIModel: Decodable, Equatable {
    let id: Int
    let text: String
    let approved_at: String?
}

struct SessionMediaAPIModel: Decodable, Equatable {
    let id: Int
    let type: String
    let url: String
    let approved_at: String?
}

struct NotificationsResponse: Decodable {
    let data: [NotificationAPIModel]
}

struct NotificationAPIModel: Decodable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let is_read: Bool
    let created_at: String
    let data: NotificationDataAPIModel?
}

struct NotificationDataAPIModel: Decodable {
    let session_id: Int?
    let child_id: Int?
    let date: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // session_id may arrive as Int or String from the backend
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .session_id) {
            session_id = intVal
        } else if let strVal = try? c.decodeIfPresent(String.self, forKey: .session_id) {
            session_id = Int(strVal)
        } else {
            session_id = nil
        }
        child_id = try? c.decodeIfPresent(Int.self, forKey: .child_id) ?? {
            if let s = try? c.decodeIfPresent(String.self, forKey: .child_id) { return Int(s) }
            return nil
        }()
        date = try? c.decodeIfPresent(String.self, forKey: .date)
    }

    private enum CodingKeys: String, CodingKey {
        case session_id, child_id, date
    }
}
