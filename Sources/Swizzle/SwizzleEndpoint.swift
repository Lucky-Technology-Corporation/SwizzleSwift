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
            self?.outerObjectWillChange.send()
        }

        if let data = Swizzle.shared.userDefaults.data(forKey: endpoint), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            self.objectWillChange.send()
            refresh()
        }
    }
    
    public var wrappedValue: T? {
        get {
            refresh()
            return value
        }
    }

    public var projectedValue: SwizzleEndpoint { self }
    
    private func refresh() {
        Task {
            do {
                let fetchedValue: T = try await Swizzle.shared.get(endpoint)
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



@propertyWrapper
public class BasicSwizzleEndpoint<T: Codable>: ObservableObject {
    public let objectWillChange = PassthroughSubject<Void, Never>()
    @Published private(set) var value: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    let endpoint: String
    var defaultValue: T?

    public init(_ endpoint: String, defaultValue: T? = nil) {
        self.endpoint = endpoint
        self.defaultValue = defaultValue

        if let data = Swizzle.shared.userDefaults.data(forKey: endpoint), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            self.objectWillChange.send()
            refresh()
        }
    }
    
    public var wrappedValue: T? {
        get {
            refresh()  // Refresh the value from the endpoint whenever it's accessed
            return value
        }
    }

    public var projectedValue: BasicSwizzleEndpoint { self }
    
    private func refresh() {
        Task {
            do {
                let fetchedValue: T = try await Swizzle.shared.get(endpoint)
                DispatchQueue.main.async {
                    self.value = fetchedValue
                    self.objectWillChange.send()
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
    
    public func refreshFromCache(){
        if let data = Swizzle.shared.userDefaults.data(forKey: endpoint), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            self.objectWillChange.send()
        }
    }
}
