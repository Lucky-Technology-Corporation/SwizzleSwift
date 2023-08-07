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
    @Published var value: T? {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
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
            self.objectWillChange.send()
            refresh()
        }
        
        observer = NotificationCenter.default.addObserver(forName: .swizzleModelUpdated, object: nil, queue: nil) { [weak self] _ in
            self?.refreshFromCache()
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public var wrappedValue: T? {
        get { value }
        set {
            DispatchQueue.main.async { [weak self] in
                self?.value = newValue
            }
            if let newValue = newValue {
                Swizzle.shared.saveValue(newValue, forKey: key)
                NotificationCenter.default.post(name: .swizzleStorageUpdated, object: nil)
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
                self?.objectWillChange.send()
                do {
                    let data = try JSONEncoder().encode(fetchedValue)
                    Swizzle.shared.userDefaults.set(data, forKey: self?.key ?? "")
                } catch { }
            }
        }
    }
    
    public func refreshFromCache(){
        if let data = Swizzle.shared.userDefaults.data(forKey: key), let loadedValue = try? JSONDecoder().decode(T.self, from: data) {
            self.value = loadedValue
            self.objectWillChange.send()
        }
    }
    
}


public class SwizzleModel<T: Codable>: ObservableObject {
    @SwizzleStorage("") public var object: T? {
        didSet{
            NotificationCenter.default.post(name: .swizzleModelUpdated, object: nil)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    public init(_ key: String, defaultValue: T? = nil) {
        _object = SwizzleStorage(key, defaultValue: defaultValue)
        _object.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateValue), name: .swizzleStorageUpdated, object: nil)
    }
    
    @objc func updateValue(){
        _object.refreshFromCache()
    }
    
    public func refresh(){
        _object.refresh()
    }
}
