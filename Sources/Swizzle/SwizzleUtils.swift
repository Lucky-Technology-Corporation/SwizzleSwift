import Foundation
import Security
import Combine

#if canImport(UIKit)
import UIKit
#endif

extension Swizzle {
    
    func getUniqueDeviceIdentifier() -> String? {
        let account = "SwizzleDeviceId"

        let accountData = account.data(using: String.Encoding.utf8)!
        let getQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: accountData,
                                       kSecReturnData as String: kCFBooleanTrue!,
                                       kSecMatchLimit as String: kSecMatchLimitOne]

        var dataTypeRef: AnyObject?
        let getStatus: OSStatus = SecItemCopyMatching(getQuery as CFDictionary, &dataTypeRef)

        if getStatus == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let uid = String(data: retrievedData, encoding: String.Encoding.utf8) {
                return uid
            }
        }
        
        
        var uid: String = UUID().uuidString
        
        #if canImport(UIKit)
        uid = UIDevice.current.identifierForVendor!.uuidString
        #endif
        
        let uidData = uid.data(using: String.Encoding.utf8)!

        let addQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: accountData,
                                       kSecValueData as String: uidData]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            print("Couldn't save UID to Keychain: \(addStatus)")
        }
        return uid
    }
}

struct SwizzleLoginResponse: Codable {
    let userId: String?
    let accessToken: String
    let refreshToken: String
}

enum SwizzleError: LocalizedError {
    case swizzleNotInitialized
    case unauthenticated
    case badImage
    case badURL
    case badFormat
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .swizzleNotInitialized:
            return NSLocalizedString("Swizzle has not been initialized yet. Call Swizzle.shared.configure(projectId: \"YourProjectID\") before making any requests", comment: "Uninitialized")
        case .unauthenticated:
            return NSLocalizedString("This user doesn't have permission to access this resource", comment: "Unauthenticated")
        case .badImage:
            return NSLocalizedString("This image is not the right format", comment: "Incorrect image format")
        case .badURL:
            return NSLocalizedString("This URL is not correct", comment: "Incorrect URL format")
        case .badFormat:
            return NSLocalizedString("The input is not in the right format", comment: "Incorrect format")
        case .permissionDenied:
            return NSLocalizedString("The app doesn't have enough permissions to complete the request", comment: "Permission denied")
        }
    }
}
#if canImport(UIKit)
extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let widthRatio  = targetSize.width  / self.size.width
        let heightRatio = targetSize.height / self.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
#endif

extension String{
    func isISOPhoneNumberFormat() -> Bool {
        let pattern = "^\\+[0-9]{11,15}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        return regex?.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil
    }
}


extension Notification.Name {
    static let swizzleModelUpdated = Notification.Name("swizzleModelUpdated")
    static let swizzleStorageUpdated = Notification.Name("swizzleStorageUpdated")
}

struct Wrapped<T: Codable>: Codable {
    let value: T
}

extension Swizzle{
    public static func bindToUI<T: ObservableObject>(_ object: T) {
        for child in Mirror(reflecting: object).children {
            if let child = child.value as? Swizzleable {
                child.bindPublisher(object.objectWillChange as! ObservableObjectPublisher)
            }
        }
    }
    
    func addQueryParameters(_ params: [String: AnyObject], to baseURL: URL) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        
        components?.queryItems = params.map { (key, value) in
            return URLQueryItem(name: key, value: String(describing: value))
        }
        
        return components?.url ?? baseURL
    }
}

protocol Swizzleable {
    func bindPublisher(_ publisher: ObservableObjectPublisher)
}

