//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/6/23.
//

import Foundation
import Combine


@propertyWrapper
public class SwizzleData<T: Codable>: ObservableObject, Swizzleable {
    private var cancellable: AnyCancellable?
    private weak var parentPublisher: ObservableObjectPublisher?

    private var innerValue: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.parentPublisher?.send()
            }
        }
    }

    public var wrappedValue: T? {
        get { innerValue }
        set {
            innerValue = newValue
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

    public var projectedValue: SwizzleData { self }

    let key: String
    var defaultValue: T?

    public init(key: String) {
        self.key = key
        
        if let data = Swizzle.shared.userDefaults.data(forKey: key), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.innerValue = loadedValue
        }

        refresh()
    }
    
    public func bindPublisher(_ publisher: ObservableObjectPublisher) {
        parentPublisher = publisher
    }
    
    public func refresh() {
        Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
            DispatchQueue.main.async {
                if let dict = fetchedValue as? [String: Codable], dict.count == 1, let value = dict["value"] as? T {
                    self?.innerValue = value
                } else{
                    self?.innerValue = fetchedValue
                }
                do {
                    let data = try JSONEncoder().encode(fetchedValue)
                    Swizzle.shared.userDefaults.set(data, forKey: self?.key ?? "")
                } catch { }
            }
        }
    }
}

