import Foundation
import XCTest

@testable import USBBenchCore

final class SystemInspectorTests: XCTestCase {
  func testPropertyListCommandTimesOutPromptly() {
    let started = Date()

    let result = SystemInspector.propertyListOutput(
      executableURL: URL(fileURLWithPath: "/bin/sleep"),
      arguments: ["2"],
      timeout: 0.05
    )

    XCTAssertTrue(result.isEmpty)
    XCTAssertLessThan(Date().timeIntervalSince(started), 1)
  }
}
