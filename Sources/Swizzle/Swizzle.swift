import SwiftUI
import Combine

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

    /**
    Configures the project ID and the test environment.

    - Parameters:
      - projectId: The ID of the project to construct the base URL.
      - test: A Boolean flag that determines whether the API should point to the test environment. The default value is `true`.
    */
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
        Task {
            await waitForAuthentication()

            do {
                let deviceData: T = try await get("/swizzle/db/\(key)/")
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
                    print("[Swizzle] Failed to fetch data for key \(key): \(error)")
                    DispatchQueue.main.async {
                        completion(defaultValue)
                    }
                }
            }
        }
    }

    func saveValue<T: Codable>(_ value: T, forKey key: String) {
        guard let apiBaseURL = apiBaseURL else { return }
        
        do {
            let data = try JSONEncoder().encode(value)
            Swizzle.shared.userDefaults.set(data, forKey: key)
        } catch {
            print("[Swizzle] Failed to save \(key) locally")
        }
        
        let queryURL = apiBaseURL.appendingPathComponent("swizzle/db/\(key)/")
        Task {
            await waitForAuthentication()

            do {
                try await post(queryURL, data: value)
            } catch {
                print("[Swizzle] Failed to save \(key) remotely")
            }
        }
    }
    
    //Easy function call helpers
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
    /**
    Uploads a given image to a specified endpoint with adjustable quality and size.

    The function first resizes the input image to the specified size (default 200x200) and compresses it with the specified quality (default 0.7). The compressed image is then encoded into a base64 string, which is posted to the endpoint appended to the `apiBaseURL`.

    This function is asynchronous and throws errors for various failure conditions like `Swizzle` not being initialized, bad image data or bad URL response.

    - Parameters:
      - image: The `UIImage` that you want to upload.
      - size: The target size to which the image should be resized. The default value is `CGSize(width: 200, height: 200)`.
      - compressionQuality: The quality of the output JPEG representation of the image, expressed as a value from 0.0 to 1.0. The value 0.0 represents the maximum compression (or lowest quality) while the value 1.0 represents the least compression (or best quality). The default value is 0.7.
    - Throws: `SwizzleError.swizzleNotInitialized` if Swizzle is not initialized, `SwizzleError.badImage` if there was an issue encoding the image, or `SwizzleError.badURL` if the URL received from the server can't be interpreted correctly.
    - Returns: The URL where the image was uploaded.

    - Note: This function is only available on platforms where UIKit is available.

    - Precondition: `Swizzle.shared` must be properly initialized and able to post data.
    */
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
        let (data, response) = try await URLSession.shared.data(for: request)
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

    private func refreshOrLoginIfNeeded() {
        isAuthenticating = true
        Task {
            if let refreshToken = refreshToken {
                await refreshAccessToken(refreshToken: refreshToken)
            } else {
                await anonymousLogin()
            }
        }
    }
    
    public func sendCode(to: String) async throws{
        if(!to.isISOPhoneNumberFormat()){
            print("[Swizzle] The phone number is not in ISO format")
            throw SwizzleError.badFormat
        }
        
        let params = ["phoneNumber": to]

        do {
            try await post(apiBaseURL!.appendingPathComponent("swizzle/auth/sms/request-code"), data: params)
            return
        } catch {
            print("[Swizzle] Couldn't send SMS code: \(error)")
            return
        }
    }
    
    public func verifyCode(_ code: String) async throws -> Bool{
        if(code.count != 6){
            print("[Swizzle] The verification code must be 6 digits")
            throw SwizzleError.badFormat
        }
        
        let params = ["code": code]

        do {
            let response: SwizzleLoginResponse = try await post(apiBaseURL!.appendingPathComponent("swizzle/auth/verify-code"), data: params)
            accessToken = response.accessToken
            refreshToken = response.refreshToken
            userId = response.userId
            return true
        } catch {
            print("[Swizzle] Couldn't sign in \(error). You need to send a new code with sendCode(to: phoneNumber) to retry.")
            return false
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
            print("[Swizzle] Authentication failed: \(error)")
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
            return await anonymousLogin() // Attempt an anonymous login if token refresh fails
        }
    }
}




