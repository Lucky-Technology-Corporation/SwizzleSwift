import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

public class Swizzle {
    public static let shared = Swizzle()

    let userDefaults = UserDefaults.standard

    var accessToken: String? {
        didSet {
            userDefaults.setValue(accessToken, forKey: "accessTokenSwizzle")
            isAuthenticating = false
        }
    }
    
    var refreshToken: String? {
        didSet {
            userDefaults.setValue(refreshToken, forKey: "refreshTokenSwizzle")
        }
    }
    
    var userId: String? {
        didSet {
            userDefaults.setValue(userId, forKey: "userIdSwizzle")
        }
    }
    
    var deviceId: String?

    var isAuthenticating: Bool = false

    var apiBaseURL: URL? = nil {
        didSet {
            self.deviceId = getUniqueDeviceIdentifier()
            if let _ = apiBaseURL, deviceId != nil {
                self.accessToken = userDefaults.string(forKey: "accessTokenSwizzle")
                self.refreshToken = userDefaults.string(forKey: "refreshTokenSwizzle")
                self.userId = userDefaults.string(forKey: "userIdSwizzle")
                self.refreshOrLoginIfNeeded()
            }
        }
    }

    private init() { }

    
    public func configure(projectId: String, test: Bool = true) {
//        var url = "https://\(projectId).swizzle.run"
//        if(test){
//            url = "https://wealth-leaderboard-backend.vercel.app/"
//        } else{
//            print("[Swizzle] ERROR - your production environment has not been set up!")
//            return
//        }
        var url = projectId
        apiBaseURL = URL(string: url)
    }
    
    
    //Easy function call getters
    public func get<T: Decodable>(_ functionName: String) async throws -> T {
        await waitForAuthentication()
        return try await getCodable(functionName)
    }
    
    public func get(_ functionName: String) async throws -> String {
        await waitForAuthentication()
        return try await getString(functionName)
    }
    
    public func get(_ functionName: String) async throws -> Int {
        await waitForAuthentication()
        return try await getInt(functionName)
    }
    
    public func get(_ functionName: String) async throws -> Double {
        await waitForAuthentication()
        return try await getDouble(functionName)
    }
    
    public func get(_ functionName: String) async throws -> Bool {
        await waitForAuthentication()
        return try await getBool(functionName)
    }
    
    
    public func post<T: Encodable>(ignoringResponseFrom functionName: String, data: T) async throws {
        await waitForAuthentication()
        return try await postEmpty(functionName, data: data)
    }
    
    public func post<T: Encodable, U: Decodable>(_ functionName: String, data: T) async throws -> U {
        await waitForAuthentication()
        return try await postCodable(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws -> String {
        await waitForAuthentication()
        return try await postString(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws -> Int {
        await waitForAuthentication()
        return try await postInt(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws -> Double {
        await waitForAuthentication()
        return try await postDouble(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws -> Bool {
        await waitForAuthentication()
        return try await postBool(functionName, data: data)
    }
    
    public func getBaseURL() -> URL?{
        return apiBaseURL
    }
    
    public func getUserId() -> String?{
        return userId
    }
    
    public func getFullUrl(for functionName: String, with parameters: [String: Any]?) -> URL? {
        guard let baseUrl = apiBaseURL else { return nil }
        var fullUrl = baseUrl.appendingPathComponent(functionName)
    
        if let params = parameters{
            fullUrl = addQueryParameters(params, to: fullUrl)
        }
        
        return fullUrl
    }
    
    struct ImageUpload: Codable {
        var data: String
    }
    
    struct ImageUploadResult: Codable {
        var url: String
    }
    
    #if canImport(UIKit)
    public func upload(image: UIImage, size: CGSize = CGSize(width: 200, height: 200), compressionQuality: CGFloat = 0.7) async throws -> URL{
        let imageData = image.resized(to: size)?.jpegData(compressionQuality: compressionQuality)
        guard let base64String = imageData?.base64EncodedString() else { throw SwizzleError.badImage }

        let response: ImageUploadResult = try await self.post("swizzle/db/storage", data: ImageUpload(data: base64String))
        guard let url = URL(string: response.url) else {
            throw SwizzleError.badURL
        }
        return url
    }
    #endif

    
    //REST APIs
    func getData(_ functionName: String) async throws -> Data {
        let request = try buildGetRequest(functionName)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    func getCodable<T: Decodable>(_ functionName: String) async throws -> T {
        let request = try buildGetRequest(functionName)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
    }
    
    func getString(_ functionName: String) async throws -> String {
        let request = try buildGetRequest(functionName)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string
    }
    
    func getInt(_ functionName: String) async throws -> Int {
        let request = try buildGetRequest(functionName)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let int = Int(string) else {
            throw URLError(.badServerResponse)
        }
        return int
    }
    
    func getDouble(_ functionName: String) async throws -> Double {
        let request = try buildGetRequest(functionName)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let double = Double(string) else {
            throw URLError(.badServerResponse)
        }
        return double
    }
    
    func getBool(_ functionName: String) async throws -> Bool {
        let request = try buildGetRequest(functionName)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let bool = Bool(string) else {
            throw URLError(.badServerResponse)
        }
        return bool
    }


    func postEmpty<T: Encodable>(_ functionName: String, data: T) async throws {
        let request = try buildPostRequest(functionName, data: data)
        _ = try await URLSession.shared.data(for: request)
    }

    func postCodable<T: Encodable, U: Decodable>(_ functionName: String, data: T) async throws -> U {
        let request = try buildPostRequest(functionName, data: data)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(U.self, from: responseData)
        return response
    }
    
    func postString<T: Encodable>(_ functionName: String, data: T) async throws -> String {
        let request = try buildPostRequest(functionName, data: data)
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: responseData, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string
    }

    func postInt<T: Encodable>(_ functionName: String, data: T) async throws -> Int {
        let request = try buildPostRequest(functionName, data: data)
        let (responseData, _) = try await URLSession.shared.data(for: request)

        guard let string = String(data: responseData, encoding: .utf8),
              let int = Int(string) else {
            throw URLError(.badServerResponse)
        }
        return int
    }
    
    func postDouble<T: Encodable>(_ functionName: String, data: T) async throws -> Double {
        let request = try buildPostRequest(functionName, data: data)
        let (responseData, _) = try await URLSession.shared.data(for: request)

        guard let string = String(data: responseData, encoding: .utf8),
              let double = Double(string) else {
            throw URLError(.badServerResponse)
        }
        return double
    }
    
    func postBool<T: Encodable>(_ functionName: String, data: T) async throws -> Bool {
        let request = try buildPostRequest(functionName, data: data)
        let (responseData, _) = try await URLSession.shared.data(for: request)

        guard let string = String(data: responseData, encoding: .utf8),
              let bool = Bool(string) else {
            throw URLError(.badServerResponse)
        }
        return bool
    }
}




