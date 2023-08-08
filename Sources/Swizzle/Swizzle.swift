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
        var url = "https://\(projectId).swizzle.run"
        if(test){
            url = "https://wealth-leaderboard-backend.vercel.app/"
        } else{
            print("[Swizzle] ERROR - your production environment has not been set up!")
            return
        }
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
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws {
        await waitForAuthentication()
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await post(queryURL, data: data)
    }
    
    public func post<T: Encodable, U: Decodable>(_ functionName: String, data: T) async throws -> U {
        await waitForAuthentication()
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await post(queryURL, data: data)
    }
    
    struct ImageUpload: Codable {
        var data: String
    }
    
    struct ImageUploadResult: Codable {
        var url: String
    }
    
    #if canImport(UIKit)
    public func upload(image: UIImage, size: CGSize = CGSize(width: 200, height: 200), compressionQuality: CGFloat = 0.7) async throws -> URL{
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let imageData = image.resized(to: size)?.jpegData(compressionQuality: compressionQuality)
        guard let base64String = imageData?.base64EncodedString() else { throw SwizzleError.badImage }
        let queryURL = apiBaseURL.appendingPathComponent("swizzle/db/storage")
        let response: ImageUploadResult = try await self.post(queryURL, data: ImageUpload(data: base64String))
        guard let url = URL(string: response.url) else {
            throw SwizzleError.badURL
        }
        return url
    }
    #endif

    
    //REST APIs
    func getData(_ functionName: String) async throws -> Data {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    func getCodable<T: Decodable>(_ functionName: String) async throws -> T {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
    }
    
    func getString(_ functionName: String) async throws -> String {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string
    }
    
    func getInt(_ functionName: String) async throws -> Int {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let int = Int(string) else {
            throw URLError(.badServerResponse)
        }
        return int
    }
    
    func getDouble(_ functionName: String) async throws -> Double {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let double = Double(string) else {
            throw URLError(.badServerResponse)
        }
        return double
    }
    
    func getBool(_ functionName: String) async throws -> Bool {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let url = apiBaseURL.appendingPathComponent(functionName)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8),
              let bool = Bool(string) else {
            throw URLError(.badServerResponse)
        }
        return bool
    }


    func post<T: Encodable>(_ url: URL, data: T) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        request.httpBody = jsonData
        _ = try await URLSession.shared.data(for: request)
    }

    func post<T: Encodable, U: Decodable>(_ url: URL, data: T) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        request.httpBody = jsonData
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        
        let response = try decoder.decode(U.self, from: responseData)
        
        return response
    }

}




