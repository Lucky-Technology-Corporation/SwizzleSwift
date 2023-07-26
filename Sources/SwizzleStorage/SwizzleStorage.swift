import SwiftUI
import NIOPosix
import MongoSwift

public class Swizzle {
    public static let shared = Swizzle()
    var client: MongoClient?
    var database: MongoDatabase?
    var collection: MongoCollection<BSONDocument>?
    let userDefaults = UserDefaults.standard // UserDefaults as cache
    
    private init() {} // Prevent clients from creating another instance.
    
    public func configure(projectId: String, test: Bool = false) {
        
        let url = URL(string: "https://euler-i733tg4iuq-uc.a.run.app/api/v1/"+projectId)
        Task {
            do {
                // Fetch connectionString from server
                let connectionString = try await fetchConnectionString(from: url!)
                
                let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
                client = try? MongoClient(connectionString, using: elg)
                database = client?.db(projectId)
                collection = database?.collection("device_data")
            } catch {
                // handle errors
                print("Error configuring MongoDBManager: \(error)")
            }
        }
    }
    
    private func fetchConnectionString(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let connectionString = json?["connectionString"] as? String else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse connectionString"])
        }
        return connectionString
    }

    func loadValue<T: Codable>(forKey key: String, defaultValue: T?, completion: @escaping (T?) -> Void) {
        guard let deviceId = getUniqueDeviceIdentifier() else { return }

        Task {
            do {
                guard let collection = self.collection else { return }
                let query: BSONDocument = ["deviceId": .string(deviceId)]
                let document = try await collection.findOne(query)
                if let jsonData = document?[key]?.stringValue?.data(using: .utf8),
                   let fetchedValue = try? JSONDecoder().decode(T.self, from: jsonData) {
                    DispatchQueue.main.async {
                        completion(fetchedValue)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(defaultValue)
                    }
                }
            } catch {
                print("Failed to fetch data for key \(key): \(error)")
                DispatchQueue.main.async {
                    completion(defaultValue)
                }
            }
        }
    }

    func saveValue<T: Codable>(_ value: T?, forKey key: String) {
        guard let deviceId = getUniqueDeviceIdentifier() else { return }
        
        Task {
            do {
                guard let collection = self.collection else { return }
                let query: BSONDocument = ["deviceId": .string(deviceId)]
                
                if let value = value,
                   let jsonData = try? JSONEncoder().encode(value),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    let update: BSONDocument = ["$set": .document([key: .string(jsonString)])]
                    try await collection.updateOne(filter: query, update: update, options: UpdateOptions(upsert: true))
                } else {
                    let update: BSONDocument = ["$unset": .document([key: .int32(1)])]
                    try await collection.updateOne(filter: query, update: update)
                }
            } catch {
                print("Failed to store data for key \(key): \(error)")
            }
        }
    }
    
    func getUniqueDeviceIdentifier() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString?.takeUnretainedValue() as? String
    }
    
    
    //APIs
    func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
    }

    // Make a POST request, sending JSON, and decode the response
    func post<T: Decodable>(_ url: URL, data: [String: Any]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        let response = try decoder.decode(T.self, from: data)
        return response
    }

}

@propertyWrapper
public class SwizzleStorage<T: Codable>: ObservableObject {
    @Published private var value: T?
    let key: String

    public var wrappedValue: T? {
        get { value }
        set {
            value = newValue
            if let newValue = newValue {
                Swizzle.shared.saveValue(newValue, forKey: key)
            }
        }
    }

    public init(_ key: String, defaultValue: T? = nil) {
        self.key = key
        if let data = Swizzle.shared.userDefaults.data(forKey: key),
           let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
        } else {
            self.value = defaultValue
            if let defaultValue = defaultValue {
                Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
                    DispatchQueue.main.async {
                        self?.value = fetchedValue
                    }
                }
            }
        }
    }
}
