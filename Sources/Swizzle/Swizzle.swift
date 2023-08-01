import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public class Swizzle {
    public static let shared = Swizzle()

    let userDefaults = UserDefaults.standard

    private(set) var accessToken: String? {
        didSet {
            userDefaults.setValue(accessToken, forKey: "accessTokenSwizzle")
            isAuthenticating = false
        }
    }
    
    private(set) var refreshToken: String? {
        didSet {
            userDefaults.setValue(refreshToken, forKey: "refreshTokenSwizzle")
        }
    }
    
    private(set) var userId: String? {
        didSet {
            userDefaults.setValue(userId, forKey: "userIdSwizzle")
        }
    }
    
    private(set) var deviceId: String?

    private var isAuthenticating: Bool = false

    private var apiBaseURL: URL? = nil {
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
    
    //Load and save to DB
    func loadValue<T: Codable>(forKey key: String, defaultValue: T?, completion: @escaping (T?) -> Void) {
        guard let apiBaseURL = apiBaseURL else { return }
        
        let queryURL = apiBaseURL.appendingPathComponent("swizzle/db/\(key)/")
        Task {
            do {
                let deviceData: T = try await get(queryURL)
                DispatchQueue.main.async {
                    completion(deviceData)
                }
            } catch {
                if let decodingError = error as? DecodingError,
                   case .keyNotFound = decodingError {
                    DispatchQueue.main.async {
                        completion(defaultValue)
                    }
                } else {
                    print("Failed to fetch data for key \(key): \(error)")
                    DispatchQueue.main.async {
                        completion(defaultValue)
                    }
                }
            }
        }
    }

    func saveValue<T: Codable>(_ value: T, forKey key: String) {
        guard let apiBaseURL = apiBaseURL else { return }
        
        let queryURL = apiBaseURL.appendingPathComponent("swizzle/db/\(key)/")
        Task {
            do {
                try await post(queryURL, data: value)
            } catch {
                print("Failed to store data for key \(key): \(error)")
            }
        }
    }
    
    //Easy function call helpers
    public func get<T: Decodable>(_ functionName: String) async throws -> T {
        await waitForAuthentication()
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await get(queryURL)
    }
    
    public func get(_ functionName: String) async throws -> String {
        await waitForAuthentication()
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await getString(queryURL)
    }
    
    public func get(_ functionName: String) async throws -> Int {
        await waitForAuthentication()
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await getInt(queryURL)
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
    public func upload(image: UIImage) async throws -> URL{
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let imageData = image.jpegData(compressionQuality: 0.5)
        guard let base64String = imageData?.base64EncodedString() else { throw SwizzleError.badImage }
        let queryURL = apiBaseURL.appendingPathComponent("swizzle/db/storage")
        print(queryURL)
        let response: ImageUploadResult = try await self.post(queryURL, data: ImageUpload(data: base64String))
        print(response.url)
        guard let url = URL(string: response.url) else {
            throw SwizzleError.badURL
        }
        return url
    }
    #endif

    
    //REST APIs
    func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
    }
    
    func getString(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string
    }
    
    func getInt(_ url: URL) async throws -> Int {
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
    
    private func waitForAuthentication() async {
        while isAuthenticating {
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // Sleeps for 0.1 seconds
            } catch {
                print(error)
            }
        }
    }

    //AUTH - HERE IS THE ISSUe!
    func refreshOrLoginIfNeeded() {
        isAuthenticating = true
        Task {
            if let refreshToken = refreshToken {
                await refreshAccessToken(refreshToken: refreshToken)
            } else {
                await anonymousLogin()
            }
        }
    }
    
    private func anonymousLogin() async {
        let params = ["deviceId": deviceId]

        do {
            let response: SwizzleLoginResponse = try await post(apiBaseURL!.appendingPathComponent("swizzle/auth/anonymous"), data: params)
            accessToken = response.accessToken
            refreshToken = response.refreshToken
            userId = response.userId
            return
        } catch {
            print("Anonymous login failed: \(error)")
            isAuthenticating = false
            return
        }
    }

    private func refreshAccessToken(refreshToken: String) async {
        let params = ["refreshToken": refreshToken, "deviceId": deviceId]
        
        do {
            let response: SwizzleLoginResponse = try await post(apiBaseURL!.appendingPathComponent("swizzle/auth/refresh"), data: params)
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
        } catch {
            print("Failed to refresh access token: \(error)")
            return await anonymousLogin() // Attempt an anonymous login if token refresh fails
        }
    }
}

@propertyWrapper
public class SwizzleStorage<T: Codable>: ObservableObject {
    @Published private var value: T?
    let key: String
    var defaultValue: T?
    
    public var wrappedValue: T? {
        get { value }
        set {
            value = newValue
            if let newValue = newValue {
                Swizzle.shared.saveValue(newValue, forKey: key)
            } else {
                print("[Swizzle] Can't update a property of a nil object")
            }
        }
    }
    
    public init(_ key: String, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        
        if let data = Swizzle.shared.userDefaults.data(forKey: key), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            refresh() //refresh after
        } else {
            self.value = defaultValue
            refresh()
        }
    }
    
    public func refresh(completion: ((T?) -> Void)? = nil) {
        Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
            DispatchQueue.main.async {
                self?.value = fetchedValue
            }
        }
    }
}
