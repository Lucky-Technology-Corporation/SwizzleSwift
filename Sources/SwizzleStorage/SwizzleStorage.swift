import SwiftUI

public class Swizzle {
    public static let shared = Swizzle()
    let userDefaults = UserDefaults.standard
    
    private(set) var accessToken: String? {
        didSet {
            userDefaults.setValue(accessToken, forKey: "accessTokenSwizzle")
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
        
        let queryURL = apiBaseURL.appendingPathComponent("/swizzle/db/\(key)/")
        Task {
            do {
                let deviceData: T = try await get(queryURL, expecting: T.self)
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
        
        let queryURL = apiBaseURL.appendingPathComponent("/swizzle/db/\(key)/")
        Task {
            do {
                try await post(queryURL, data: value)
            } catch {
                print("Failed to store data for key \(key): \(error)")
            }
        }
    }
    
    //Easy function call helpers
    public func get<T: Decodable>(_ functionName: String, expecting type: T.Type) async throws -> T {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await get(queryURL, expecting: type)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T) async throws {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await post(queryURL, data: data)
    }
    
    public func post<T: Encodable, U: Decodable>(_ functionName: String, data: T) async throws -> U {
        guard let apiBaseURL = apiBaseURL else { throw SwizzleError.swizzleNotInitialized }
        let queryURL = apiBaseURL.appendingPathComponent(functionName)
        return try await post(queryURL, data: data)
    }
    
    
    //REST APIs
    func get<T: Decodable>(_ url: URL, expecting type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
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

    
    //AUTH
    func refreshOrLoginIfNeeded() {
        if let refreshToken = refreshToken {
            refreshAccessToken(refreshToken: refreshToken)
        } else {
            anonymousLogin()
        }
    }
    
    private func anonymousLogin() {
        let params = ["deviceId": deviceId]
        Task {
            do {
                let response: SwizzleLoginResponse = try await post(apiBaseURL!.appendingPathComponent("/swizzle/auth/anonymous"), data: params)
                accessToken = response.accessToken
                refreshToken = response.refreshToken
            } catch {
                print("Anonymous login failed: \(error)")
            }
        }
    }

    private func refreshAccessToken(refreshToken: String) {
        let params = ["refreshToken": refreshToken]
        Task {
            do {
                let response: SwizzleLoginResponse = try await post(apiBaseURL!.appendingPathComponent("/swizzle/auth/refresh"), data: params)
                accessToken = response.accessToken
            } catch {
                print("Failed to refresh access token: \(error)")
                anonymousLogin() // Attempt an anonymous login if token refresh fails
            }
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
