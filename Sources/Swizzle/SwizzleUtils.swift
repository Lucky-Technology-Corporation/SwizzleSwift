import Foundation
import Security

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
        
        let uid: String = UUID().uuidString
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
    
    var errorDescription: String? {
        switch self {
        case .swizzleNotInitialized:
            return NSLocalizedString("Swizzle has not been initialized yet. Call Swizzle.shared.configure(projectId: \"YourProjectID\") before making any requests", comment: "Uninitialized")
        case .unauthenticated:
            return NSLocalizedString("This user doesn't have permission to access this resource", comment: "Unauthenticated")
        case .badImage:
            return NSLocalizedString("This image is not the right format", comment: "Bad image")

        }
    }
}

