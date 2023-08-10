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
                if !(isStruct(newValue)) {
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

    public init(_ key: String) {
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
                } catch { 
                    print(error)
                }
            }
        }
    }
    
    func isStruct(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .struct
    }

}

extension Swizzle{
    func loadValue<T: Codable>(forKey key: String, defaultValue: T?, completion: @escaping (T?) -> Void) {
        Task {
            await waitForAuthentication()

            do {
                let data = try await getData("swizzle/db/\(key)/")

                if let decodedData = try? JSONDecoder().decode(T.self, from: data) {
                    DispatchQueue.main.async {
                        completion(decodedData)
                    }
                    return
                }

                // If direct decoding fails, try decoding using the wrapper
                if let wrappedData = try? JSONDecoder().decode(Wrapped<T>.self, from: data) {
                    DispatchQueue.main.async {
                        completion(wrappedData.value)
                    }
                    return
                }

                // If both decodings fail, return the default value.
                DispatchQueue.main.async {
                    completion(defaultValue)
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
        do {
            let data = try JSONEncoder().encode(value)
            Swizzle.shared.userDefaults.set(data, forKey: key)
        } catch {
            print("[Swizzle] Failed to save \(key) locally")
        }
        
        Task {
            await waitForAuthentication()

            do {
                try await post(ignoringResponseFrom: "swizzle/db/\(key)/", data: value)
            } catch {
                print("[Swizzle] Failed to save \(key) remotely")
            }
        }
    }
}
