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
