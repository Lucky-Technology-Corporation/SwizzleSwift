//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/6/23.
//

import Foundation
import Combine

@propertyWrapper
public class SwizzleEndpoint<T: Codable>: ObservableObject {
    public let objectWillChange = PassthroughSubject<Void, Never>()
    private let outerObjectWillChange: ObservableObjectPublisher
    private var cancellable: AnyCancellable?
    
    @Published private(set) var value: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    let endpoint: String
    var defaultValue: T?

    public init(_ endpoint: String, outer: ObservableObjectPublisher, defaultValue: T? = nil) {
        self.endpoint = endpoint
        self.defaultValue = defaultValue
        self.outerObjectWillChange = outer
        self.cancellable = self.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.outerObjectWillChange.send()
            }
        }

        if let data = Swizzle.shared.userDefaults.data(forKey: endpoint), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            self.objectWillChange.send()
            refresh()
        }
    }
    
    public var wrappedValue: T? {
        get {
            return value
        }
    }

    public var projectedValue: SwizzleEndpoint { self }
    
    public func refresh() {
        Task {
            do {
                let fetchedValue: T
                if T.self == String.self {
                    fetchedValue = try await Swizzle.shared.getString(endpoint) as! T
                } else if T.self == Int.self {
                    fetchedValue = try await Swizzle.shared.getInt(endpoint) as! T
                } else {
                    let data = try await Swizzle.shared.getData(endpoint)
                    fetchedValue = try JSONDecoder().decode(T.self, from: data)
                }
//                let fetchedValue: T = try await Swizzle.shared.get(endpoint)
                DispatchQueue.main.async {
                    self.value = fetchedValue
                    do {
                        let data = try JSONEncoder().encode(fetchedValue)
                        Swizzle.shared.userDefaults.set(data, forKey: self.endpoint)
                    } catch { }
                }
            } catch {
                print("[Swizzle] Failed to fetch data from endpoint \(endpoint): \(error)")
            }
        }
    }
}
