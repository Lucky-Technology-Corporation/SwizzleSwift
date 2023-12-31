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
            if(userId == nil){
                isAuthenticated = false
            } else{
                isAuthenticated = true
            }
        }
    }
    
    public var isAuthenticated = false
    
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
    
    
    public func post<T: Encodable>(ignoringResponseFrom functionName: String, data: T, skipAuthenticating: Bool = false) async throws {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
        return try await postEmpty(functionName, data: data)
    }
    
    public func post<T: Encodable, U: Decodable>(decodingResponseFrom functionName: String, data: T, skipAuthenticating: Bool = false) async throws -> U {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
        return try await postCodable(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T, skipAuthenticating: Bool = false) async throws -> String {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
        return try await postString(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T, skipAuthenticating: Bool = false) async throws -> Int {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
        return try await postInt(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T, skipAuthenticating: Bool = false) async throws -> Double {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
        return try await postDouble(functionName, data: data)
    }
    
    public func post<T: Encodable>(_ functionName: String, data: T, skipAuthenticating: Bool = false) async throws -> Bool {
        if(!skipAuthenticating){
            await waitForAuthentication()
        }
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
    public func upload(image: UIImage, size: CGSize = CGSize(width: 500, height: 500), compressionQuality: CGFloat = 0.7) async throws -> URL{
        do{
            let imageData = image.resized(to: size)?.jpegData(compressionQuality: compressionQuality)
            guard let base64String = imageData?.base64EncodedString() else { throw SwizzleError.badImage }
            
            let response: ImageUploadResult = try await self.post(decodingResponseFrom: "swizzle/db/storage", data: ImageUpload(data: base64String))
            guard let url = URL(string: response.url) else {
                throw SwizzleError.badURL
            }
            return url
        }catch{
            explain(error: error)
            throw error
        }
    }
    #endif
    
    
    //REST APIs
    func getData(_ functionName: String) async throws -> Data {
        let request = try buildGetRequest(functionName)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    func getCodable<T: Decodable>(_ functionName: String) async throws -> T {
        do{
            let request = try buildGetRequest(functionName)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(T.self, from: data)
            return response
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func getString(_ functionName: String) async throws -> String {
        do{
            let request = try buildGetRequest(functionName)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: data, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            return string
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func getInt(_ functionName: String) async throws -> Int {
        do{
            let request = try buildGetRequest(functionName)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: data, encoding: .utf8),
                  let int = Int(string) else {
                throw URLError(.badServerResponse)
            }
        return int
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func getDouble(_ functionName: String) async throws -> Double {
        do{
            let request = try buildGetRequest(functionName)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: data, encoding: .utf8),
                  let double = Double(string) else {
                throw URLError(.badServerResponse)
            }
            return double
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func getBool(_ functionName: String) async throws -> Bool {
        do{
            let request = try buildGetRequest(functionName)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: data, encoding: .utf8),
                  let bool = Bool(string) else {
                throw URLError(.badServerResponse)
            }
            return bool
        }catch{
            explain(error: error)
            throw error
        }
    }


    func postEmpty<T: Encodable>(_ functionName: String, data: T) async throws {
        let request = try buildPostRequest(functionName, data: data)
        _ = try await URLSession.shared.data(for: request)
    }

    func postCodable<T: Encodable, U: Decodable>(_ functionName: String, data: T) async throws -> U {
        do{
            let request = try buildPostRequest(functionName, data: data)
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            var response: U?
            response = try decoder.decode(U.self, from: responseData)
            return response!
        } catch{
            explain(error: error)
            throw error
        }
    }
    
    func postString<T: Encodable>(_ functionName: String, data: T) async throws -> String {
        do{
            let request = try buildPostRequest(functionName, data: data)
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            guard let string = String(data: responseData, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            return string
        }catch{
            explain(error: error)
            throw error
        }
    }

    func postInt<T: Encodable>(_ functionName: String, data: T) async throws -> Int {
        do{
            let request = try buildPostRequest(functionName, data: data)
            let (responseData, _) = try await URLSession.shared.data(for: request)
            
            guard let string = String(data: responseData, encoding: .utf8),
                  let int = Int(string) else {
                throw URLError(.badServerResponse)
            }
            return int
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func postDouble<T: Encodable>(_ functionName: String, data: T) async throws -> Double {
        do{
            let request = try buildPostRequest(functionName, data: data)
            let (responseData, _) = try await URLSession.shared.data(for: request)
            
            guard let string = String(data: responseData, encoding: .utf8),
                  let double = Double(string) else {
                throw URLError(.badServerResponse)
            }
            return double
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func postBool<T: Encodable>(_ functionName: String, data: T) async throws -> Bool {
        do{
            let request = try buildPostRequest(functionName, data: data)
            let (responseData, _) = try await URLSession.shared.data(for: request)
            
            guard let string = String(data: responseData, encoding: .utf8),
                  let bool = Bool(string) else {
                throw URLError(.badServerResponse)
            }
            return bool
        }catch{
            explain(error: error)
            throw error
        }
    }
    
    func explain(error: Error){
        //TODO: Something better here
        print(error)
    }
}




