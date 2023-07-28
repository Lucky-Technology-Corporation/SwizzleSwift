import XCTest
@testable import SwizzleStorage

final class SwizzleStorageTests: XCTestCase {

    func testSetFullObject() async throws {
        Swizzle.shared.configure(projectId: "test")

        struct GenericObject: Codable {
            var id: Int
            var name: String
            var email: String
        }
        
        @SwizzleStorage("generic_object")
        var genericObject: GenericObject?
        
        genericObject = GenericObject(id: 0, name: "first", email: "a@a.com")
        
        try await Task.sleep(nanoseconds: 5 * 1_000_000_000)  // Sleep for 1 second
        
        _genericObject.refresh()

        try await Task.sleep(nanoseconds: 5 * 1_000_000_000)  // Sleep for 1 second
        
        XCTAssertEqual(genericObject?.name, "first")
    }
    
    func testSetOnePropery() async throws {
        Swizzle.shared.configure(projectId: "test")

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
        Swizzle.shared.configure(projectId: "test")

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


}
