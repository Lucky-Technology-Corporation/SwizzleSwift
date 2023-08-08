//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/6/23.
//

import Foundation
import Combine

@propertyWrapper
public class SwizzleStorage<T: Codable>: ObservableObject {
    private var observer: NSObjectProtocol?
    public let objectWillChange = PassthroughSubject<Void, Never>()
    private let outerObjectWillChange: ObservableObjectPublisher
    private var cancellable: AnyCancellable?

    var value: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        didSet {
            DispatchQueue.main.async {
                self.outerObjectWillChange.send()
            }
        }
    }
    let key: String
    var defaultValue: T?

    public init(_ key: String, outer: ObservableObjectPublisher, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.outerObjectWillChange = outer

        if let data = Swizzle.shared.userDefaults.data(forKey: key), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
        }

        self.cancellable = self.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.outerObjectWillChange.send()
            }
        }
        
        self.objectWillChange.send()
        refresh()
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    public var wrappedValue: T? {
        get { value }
        set {
            value = newValue
            if let newValue = newValue {
                
                var valueToSend: Codable
                if !(newValue is [String: Any]) {
                    valueToSend = ["value": newValue]
                } else{
                    valueToSend = newValue
                }

                Swizzle.shared.saveValue(valueToSend, forKey: key)
            } else {
                print("[Swizzle] Can't update a property of a nil object.")
            }
        }
    }
    
    public var projectedValue: SwizzleStorage { self }
    
    public func refresh() {
        Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
            DispatchQueue.main.async {
                if let dict = fetchedValue as? [String: Codable], dict.count == 1, let value = dict["value"] as? T {
                    self?.value = value
                } else{
                    self?.value = fetchedValue
                }
                do {
                    let data = try JSONEncoder().encode(fetchedValue)
                    Swizzle.shared.userDefaults.set(data, forKey: self?.key ?? "")
                } catch { }
            }
        }
    }
}


@propertyWrapper
public class SwizzleStoragePublished<T: Codable>: ObservableObject {
    private var cancellable: AnyCancellable?
    @Published public var value: T? {
        didSet {
            if let newValue = value {
                var valueToSend: Codable
                if !(newValue is [String: Any]) {
                    valueToSend = ["value": newValue]
                } else {
                    valueToSend = newValue
                }
                Swizzle.shared.saveValue(valueToSend, forKey: key)
            } else {
                print("[Swizzle] Can't update a property of a nil object.")
            }
        }
    }
    let key: String
    var defaultValue: T?

    public init(_ key: String, defaultValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue

        if let data = Swizzle.shared.userDefaults.data(forKey: key), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
        }
        refresh()
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    public var wrappedValue: T? {
        get { value }
        set { value = newValue }
    }
    
    public var projectedValue: SwizzleStoragePublished { self }
    
    public func refresh() {
        Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
            DispatchQueue.main.async {
                if let dict = fetchedValue as? [String: Codable], dict.count == 1, let value = dict["value"] as? T {
                    self?.value = value
                } else{
                    self?.value = fetchedValue
                }
                do {
                    let data = try JSONEncoder().encode(fetchedValue)
                    Swizzle.shared.userDefaults.set(data, forKey: self?.key ?? "")
                } catch { }
            }
        }
    }
}

