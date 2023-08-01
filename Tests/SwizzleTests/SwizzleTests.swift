import XCTest
@testable import Swizzle

final class SwizzleStorageTests: XCTestCase {

    func testSetFullObject() async throws {
        Swizzle.shared.configure(projectId: "test", test: true)

        struct GenericObject: Codable {
            var id: Int
            var name: String
            var email: String
        }
        
        @SwizzleStorage("generic_object")
        var genericObject: GenericObject?
        
        genericObject = GenericObject(id: 0, name: "first", email: "a@a.com")
        
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)  // Sleep for 1 second
        
        _genericObject.refresh()

        try await Task.sleep(nanoseconds: 1 * 1_000_000_000)  // Sleep for 1 second
        
        XCTAssertEqual(genericObject?.name, "first")
    }
    
    func testSetOnePropery() async throws {
        Swizzle.shared.configure(projectId: "test", test: true)

        struct GenericObject: Codable {
            var id: Int
            var name: String
            var email: String
        }
        
        @SwizzleStorage("generic_object")
        var genericObject: GenericObject?
        
        genericObject = GenericObject(id: 0, name: "first", email: "a@a.com")
        XCTAssertEqual(genericObject?.name, "first")
        
        genericObject?.name = "second"
        
        try await Task.sleep(nanoseconds: 5 * 1_000_000_000)  // Sleep for 1 second
        
        _genericObject.refresh()
        
        try await Task.sleep(nanoseconds: 5 * 1_000_000_000)  // Sleep for 1 second
        
        XCTAssertEqual(genericObject?.name, "second")
    }
    
    func testLocalCaching() async throws {
        Swizzle.shared.configure(projectId: "test", test: true)

        struct GenericObject: Codable {
            var id: Int
            var name: String
            var email: String
        }
        
        @SwizzleStorage("generic_object")
        var genericObject: GenericObject?
        
        genericObject = GenericObject(id: 0, name: "third", email: "a@a.com")
        XCTAssertEqual(genericObject?.name, "third")
    }
    
    func testGetFunctionCall() async throws {
        struct PongStruct: Codable {
            var message: String
        }
        
        Swizzle.shared.configure(projectId: "test", test: true)
        let pong: PongStruct = try await Swizzle.shared.get("swizzle/internal/ping")
        XCTAssertEqual(pong.message, "pong")
    }
    
    func testPostFunctionCall() async throws {
        UserDefaults.standard.removeObject(forKey: "accessTokenSwizzle")
        UserDefaults.standard.removeObject(forKey: "refreshTokenSwizzle")
        UserDefaults.standard.removeObject(forKey: "userIdSwizzle")

        struct PingStruct: Codable{
            var message: String
        }
        struct PongStruct: Codable {
            var message: String
        }
        Swizzle.shared.configure(projectId: "test", test: true)
        let pong: PongStruct = try await Swizzle.shared.post("swizzle/internal/ping", data: PingStruct(message: "pong"))
        XCTAssertEqual(pong.message, "pong")
    }
    
    func testGetPlaidFunctionCall() async throws {
        Swizzle.shared.configure(projectId: "test", test: true)
        let pong: String = try await Swizzle.shared.get("plaidLinkToken")
        print(pong)
    }

}
