import XCTest
@testable import markdownskiLib

final class JSONProcessorFormatTests: XCTestCase {

    func testFormatValidJSON() {
        let result = JSONProcessor.formatJSON("{\"b\":2,\"a\":1}")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("\"a\" : 1"))
            XCTAssertTrue(output.contains("\"b\" : 2"))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testFormatInvalidJSON() {
        let result = JSONProcessor.formatJSON("{not json}")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error(let msg):
            XCTAssertTrue(msg.contains("Invalid JSON"))
        }
    }

    func testFormatEmptyString() {
        let result = JSONProcessor.formatJSON("")
        switch result {
        case .success:
            XCTFail("Expected error for empty input")
        case .error:
            break
        }
    }

    func testFormatWhitespaceOnly() {
        let result = JSONProcessor.formatJSON("   \n\t  ")
        switch result {
        case .success:
            XCTFail("Expected error for whitespace-only input")
        case .error:
            break
        }
    }

    func testFormatSortsKeys() {
        let result = JSONProcessor.formatJSON("{\"z\":1,\"a\":2}")
        switch result {
        case .success(let output):
            let aIndex = output.range(of: "\"a\"")!.lowerBound
            let zIndex = output.range(of: "\"z\"")!.lowerBound
            XCTAssertTrue(aIndex < zIndex, "Keys should be sorted alphabetically")
        case .error:
            XCTFail("Expected success")
        }
    }

    func testFormatArrayInput() {
        let result = JSONProcessor.formatJSON("[1,2,3]")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("1"))
            XCTAssertTrue(output.contains("3"))
        case .error:
            XCTFail("Expected success")
        }
    }
}

final class JSONProcessorParseTests: XCTestCase {

    func testParseValidStringLiteral() {
        let input = "\"{\\\"name\\\":\\\"Ada\\\"}\""
        let result = JSONProcessor.parseJSONString(input)
        switch result {
        case .success(let output):
            XCTAssertTrue(output.contains("\"name\""))
            XCTAssertTrue(output.contains("\"Ada\""))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testParseNonStringLiteral() {
        let result = JSONProcessor.parseJSONString("{\"a\":1}")
        switch result {
        case .success:
            XCTFail("Expected error — input is an object, not a string literal")
        case .error(let msg):
            XCTAssertTrue(msg.contains("JSON string literal"))
        }
    }

    func testParseEmptyString() {
        let result = JSONProcessor.parseJSONString("")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error:
            break
        }
    }

    func testParseStringContainingInvalidJSON() {
        let input = "\"not valid json\""
        let result = JSONProcessor.parseJSONString(input)
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error(let msg):
            XCTAssertTrue(msg.contains("does not contain valid JSON"))
        }
    }
}

final class JSONProcessorStringifyTests: XCTestCase {

    func testStringifyValidObject() {
        let result = JSONProcessor.stringifyJSON("{\"a\":1}")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.hasPrefix("\""))
            XCTAssertTrue(output.hasSuffix("\""))
            XCTAssertTrue(output.contains("\\\"a\\\""))
        case .error:
            XCTFail("Expected success")
        }
    }

    func testStringifyInvalidJSON() {
        let result = JSONProcessor.stringifyJSON("{bad}")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error(let msg):
            XCTAssertTrue(msg.contains("Invalid JSON"))
        }
    }

    func testStringifyEmptyString() {
        let result = JSONProcessor.stringifyJSON("")
        switch result {
        case .success:
            XCTFail("Expected error")
        case .error:
            break
        }
    }

    func testStringifyArray() {
        let result = JSONProcessor.stringifyJSON("[1,2,3]")
        switch result {
        case .success(let output):
            XCTAssertTrue(output.hasPrefix("\""))
            XCTAssertTrue(output.contains("[1,2,3]"))
        case .error:
            XCTFail("Expected success")
        }
    }
}
