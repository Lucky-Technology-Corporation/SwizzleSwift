//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 7/27/23.
//

import Foundation

extension Swizzle {
    func getUniqueDeviceIdentifier() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString?.takeUnretainedValue() as? String
    }
    
}

struct SwizzleLoginResponse: Codable {
    let userId: String
    let accessToken: String
    let refreshToken: String
}

enum SwizzleError: LocalizedError {
    case swizzleNotInitialized
    
    var errorDescription: String? {
        switch self {
        case .swizzleNotInitialized:
            return NSLocalizedString("Swizzle has not been initialized yet. Call Swizzle.shared.configure(projectId: \"YourProjectID\") before making any requests", comment: "Swizzle not initialized")
        }
    }
}

