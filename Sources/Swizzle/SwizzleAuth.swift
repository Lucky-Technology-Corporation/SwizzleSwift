//
//  File.swift
//  
//
//  Created by Adam Barr-Neuwirth on 8/7/23.
//

import Foundation
extension Swizzle{
    func waitForAuthentication() async {
        while isAuthenticating {
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // Sleeps for 0.1 seconds
            } catch {
                print(error)
            }
        }
    }

    func refreshOrLoginIfNeeded() {
        isAuthenticating = true
        Task {
            if let refreshToken = refreshToken {
                await refreshAccessToken(refreshToken: refreshToken)
            } else {
                await anonymousLogin()
            }
        }
    }
    
    public func sendCode(to: String) async throws{
        if(!to.isISOPhoneNumberFormat()){
            print("[Swizzle] The phone number is not in ISO format")
            throw SwizzleError.badFormat
        }
        
        let params = ["phoneNumber": to]

        do {
            try await post(ignoringResponseFrom: "swizzle/auth/sms/request-code", data: params, skipAuthenticating: true)
            return
        } catch {
            print("[Swizzle] Couldn't send SMS code: \(error)")
            return
        }
    }
    
    public func verifyCode(_ code: String) async throws -> Bool{
        if(code.count != 6){
            print("[Swizzle] The verification code must be 6 digits")
            throw SwizzleError.badFormat
        }
        
        let params = ["code": code]

        do {
            let response: SwizzleLoginResponse = try await post(decodingResponseFrom: "swizzle/auth/verify-code", data: params, skipAuthenticating: true)
            accessToken = response.accessToken
            refreshToken = response.refreshToken
            userId = response.userId
            return true
        } catch {
            print("[Swizzle] Couldn't sign in \(error). You need to send a new code with sendCode(to: phoneNumber) to retry.")
            return false
        }

    }
    
    public func deleteAccount(shouldReauthenticateAnonymously: Bool = true) async throws {
        do {
            try await post(ignoringResponseFrom: "swizzle/auth/delete-account", data: Payload.none)
            accessToken = nil
            refreshToken = nil
            userId = nil
            if(shouldReauthenticateAnonymously){
                await anonymousLogin()
            }
            return
        } catch {
            print("[Swizzle] Couldn't send SMS code: \(error)")
            return
        }
    }
    
    public func setUserMetadata(_ metadata: [String: AnyEncodable]) async throws -> Bool{
        do {
            try await post(ignoringResponseFrom: "swizzle/auth/metadata", data: metadata)
            return true
        } catch {
            print("[Swizzle] Couldn't set user metadata.")
            return false
        }
    }
    
    public func setUserPushToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        let params = ["pushToken": tokenString]
        do {
            try await post(ignoringResponseFrom: "swizzle/auth/push-token", data: params)
            return
        } catch {
            print("[Swizzle] Couldn't set user push notification token.")
            return
        }
    }


    
    private func anonymousLogin() async {
        let params = ["deviceId": deviceId]

        do {
            let response: SwizzleLoginResponse = try await post(decodingResponseFrom: "swizzle/auth/anonymous", data: params, skipAuthenticating: true)
            accessToken = response.accessToken
            refreshToken = response.refreshToken
            userId = response.userId
            return
        } catch {
            print("[Swizzle] Authentication failed: \(error)")
            isAuthenticating = false
            return
        }
    }

    func refreshAccessToken(refreshToken: String) async {
        let params = ["refreshToken": refreshToken, "deviceId": deviceId]
        
        do {
            let response: SwizzleLoginResponse = try await post(decodingResponseFrom: "swizzle/auth/refresh", data: params, skipAuthenticating: true)
            self.accessToken = response.accessToken
            self.refreshToken = response.refreshToken
        } catch {
            return await anonymousLogin() // Attempt an anonymous login if token refresh fails
        }
    }
}
