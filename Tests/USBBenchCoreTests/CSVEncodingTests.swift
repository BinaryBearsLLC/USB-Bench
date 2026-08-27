import XCTest

@testable import USBBenchCore

final class CSVEncodingTests: XCTestCase {
  func testEscapesQuotesAndAlwaysQuotesFields() {
    XCTAssertEqual(CSVEncoding.field("USB \"fast\""), "\"USB \"\"fast\"\"\"")
  }

  func testNeutralizesSpreadsheetFormulaPrefixes() {
    for prefix in ["=", "+", "-", "@", "\t", "\r"] {
      XCTAssertEqual(CSVEncoding.field("\(prefix)payload"), "\"'\(prefix)payload\"")
    }
  }

  func testDoesNotChangeOrdinaryOrWhitespacePrefixedValues() {
    XCTAssertEqual(CSVEncoding.field("USB drive"), "\"USB drive\"")
    XCTAssertEqual(CSVEncoding.field(" =not-a-leading-formula"), "\" =not-a-leading-formula\"")
  }
}
