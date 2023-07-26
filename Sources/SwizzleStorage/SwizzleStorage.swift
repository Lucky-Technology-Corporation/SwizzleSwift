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
        
        let url = URL(string: "https://your-server.com/api/endpoint")
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

    
    func loadText(forKey key: String, completion: @escaping (String) -> Void) {
        Task {
            do {
                guard let collection = self.collection else { return }
                let query: BSONDocument = ["name": .string(key)]
                let document = try await collection.findOne(query)
                let fetchedText = document?["text"]?.stringValue ?? ""
                DispatchQueue.main.async {
                    completion(fetchedText)
                }
            } catch {
                print("Failed to fetch data for key \(key): \(error)")
                DispatchQueue.main.async {
                    completion("")
                }
            }
        }
    }

    func saveText(text: String, forKey key: String) {
        Task {
            do {
                guard let collection = self.collection else { return }
                let document: BSONDocument = ["name": .string(key), "text": .string(text)]
                try await collection.insertOne(document)
            } catch {
                print("Failed to store data for key \(key): \(error)")
            }
        }
    }

}

public class SwizzleStore: ObservableObject {
    @Published var text: String
    let key: String

    init(key: String) {
        self.key = key
        if let cachedValue = Swizzle.shared.userDefaults.string(forKey: key) {
            self.text = cachedValue
        } else {
            self.text = ""
            Swizzle.shared.loadText(forKey: key) { fetchedText in
                DispatchQueue.main.async {
                    self.text = fetchedText
                }
            }
        }
    }

    func save(newValue: String) {
        Swizzle.shared.userDefaults.set(newValue, forKey: key)
        text = newValue
        Swizzle.shared.saveText(text: newValue, forKey: key)
    }
}

@propertyWrapper
struct SwizzleStorage {
    private let key: String
    private var value: String {
        didSet {
            Swizzle.shared.userDefaults.set(value, forKey: key)
            Swizzle.shared.saveText(text: value, forKey: key)
        }
    }

    var wrappedValue: String {
        get { value }
        set { value = newValue }
    }

    init(key: String) {
        self.key = key
        if let cachedValue = Swizzle.shared.userDefaults.string(forKey: key) {
            self.value = cachedValue
        } else {
            self.value = ""
            var fetchedText = ""
            Swizzle.shared.loadText(forKey: key) { text in
                fetchedText = text
            }
            self.value = fetchedText
        }
    }
}
