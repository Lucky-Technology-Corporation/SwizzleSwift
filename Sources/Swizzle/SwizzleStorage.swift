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
            self.objectWillChange.send()
            refresh()
        }

        self.cancellable = self.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.outerObjectWillChange.send()
            }
        }
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    public var wrappedValue: T? {
        get { value }
        set {
            value = newValue
            if let newValue = newValue {
                Swizzle.shared.saveValue(newValue, forKey: key)
            } else {
                print("[Swizzle] Can't update a property of a nil object.")
            }
        }
    }
    
    public var projectedValue: SwizzleStorage { self }
    
    public func refresh() {
        Swizzle.shared.loadValue(forKey: key, defaultValue: defaultValue) { [weak self] fetchedValue in
            DispatchQueue.main.async {
                self?.value = fetchedValue
                do {
                    let data = try JSONEncoder().encode(fetchedValue)
                    Swizzle.shared.userDefaults.set(data, forKey: self?.key ?? "")
                } catch { }
            }
        }
    }

}
