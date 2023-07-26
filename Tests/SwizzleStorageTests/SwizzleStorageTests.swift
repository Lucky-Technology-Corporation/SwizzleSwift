import XCTest
@testable import SwizzleStorage

final class SwizzleStorageTests: XCTestCase {
    func testExample() throws {
        // XCTest Documenation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    
    func testLocalSave() async throws {
        let key = "testKey"
        let expectedValue = "testValue"

        Swizzle.shared.configure(projectId: "test")

        @SwizzleStorage("testKey") var testValue: String
        testValue = expectedValue

        // Wait for the asynchronous save operation to complete
        await Task.sleep(1 * 1_000_000_000)  // Sleep for 1 second

        XCTAssertEqual(testValue, expectedValue)
    }

}
