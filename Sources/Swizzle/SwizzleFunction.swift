//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/6/23.
//

import Foundation
import Combine

@propertyWrapper
public class SwizzleFunction<T: Codable>: ObservableObject, Swizzleable {
    public let objectWillChange = PassthroughSubject<Void, Never>()
    private weak var parentPublisher: ObservableObjectPublisher?
    private var cancellable: AnyCancellable?
    
    @Published private var value: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.parentPublisher?.send()
            }
        }
    }
    let endpoint: String
    var defaultValue: T?

    public init(_ endpoint: String, defaultValue: T? = nil) {
        if endpoint.hasPrefix("/") {
            self.endpoint = String(endpoint.dropFirst())
        } else {
            self.endpoint = endpoint
        }
        
        self.defaultValue = defaultValue
        
        self.cancellable = self.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.parentPublisher?.send()
            }
        }

        if let data = Swizzle.shared.userDefaults.data(forKey: endpoint), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
        }
        
        self.objectWillChange.send()
        refresh()
    }
    
    public var wrappedValue: T? {
        get {
            return value
        }
        set {
            value = newValue
        }
    }

    public var projectedValue: SwizzleFunction { self }
    
    public func bindPublisher(_ publisher: ObservableObjectPublisher) {
        parentPublisher = publisher
    }
    
    public func refresh() {
        Task {
            do {
                let fetchedValue: T
                if T.self == String.self {
                    fetchedValue = try await Swizzle.shared.getString(endpoint) as! T
                } else if T.self == Int.self {
                    fetchedValue = try await Swizzle.shared.getInt(endpoint) as! T
                } else if T.self == Bool.self {
                    fetchedValue = try await Swizzle.shared.getBool(endpoint) as! T
                } else if T.self == Double.self {
                    fetchedValue = try await Swizzle.shared.getDouble(endpoint) as! T
                } else {
                    let data = try await Swizzle.shared.getData(endpoint)
                    fetchedValue = try JSONDecoder().decode(T.self, from: data)
                }

                DispatchQueue.main.async {
                    self.value = fetchedValue
                    do {
                        let data = try JSONEncoder().encode(fetchedValue)
                        Swizzle.shared.userDefaults.set(data, forKey: self.endpoint)
                    } catch { }
                }
            } catch {
                print("[Swizzle] Endpoint failed: /\(endpoint) (\(error))odel")
            }
        }
    }
}
