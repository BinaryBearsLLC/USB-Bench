import Foundation
import XCTest

@testable import USBBenchCore

final class BenchmarkEngineTests: XCTestCase {
  func testSmallCompleteRunProducesMetricsAndCleansTemporaryFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let configuration = BenchmarkConfiguration(
      targetDirectory: directory,
      fileSizeBytes: Int64(8 * 1_024 * 1_024),
      passes: 2,
      selection: .all,
      randomDurationSeconds: 0.08,
      verifiesIntegrity: true
    )

    let measurement = try BenchmarkEngine.run(configuration: configuration)

    XCTAssertGreaterThan(measurement.sequentialWriteMBps ?? 0, 0)
    XCTAssertGreaterThan(measurement.sequentialReadMBps ?? 0, 0)
    XCTAssertGreaterThan(measurement.randomReadIOPS ?? 0, 0)
    XCTAssertGreaterThan(measurement.randomWriteIOPS ?? 0, 0)
    XCTAssertTrue(measurement.integrityVerified)
    XCTAssertEqual(
      measurement.measurementProtocolVersion,
      BenchmarkEngine.measurementProtocolVersion
    )
    XCTAssertEqual(measurement.cachePolicy, "F_NOCACHE")
    XCTAssertEqual(try temporaryBenchmarkFiles(in: directory), [])
  }

  func testSequentialProfileExcludesRandomAndProgressNeverRegresses() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let fractions = FractionRecorder()

    let measurement = try BenchmarkEngine.run(
      configuration: .init(
        targetDirectory: directory,
        fileSizeBytes: Int64(8 * 1_024 * 1_024),
        passes: 2,
        selection: .sequential,
        verifiesIntegrity: true
      )
    ) { update in
      fractions.append(update.fraction)
    }

    XCTAssertNotNil(measurement.sequentialWriteMBps)
    XCTAssertNotNil(measurement.sequentialWriteDurableMBps)
    XCTAssertNotNil(measurement.sequentialReadMBps)
    XCTAssertNil(measurement.randomReadIOPS)
    XCTAssertNil(measurement.randomWriteIOPS)
    XCTAssertTrue(measurement.integrityVerified)
    let recordedFractions = fractions.values
    XCTAssertTrue(
      zip(recordedFractions, recordedFractions.dropFirst()).allSatisfy { $0 <= $1 }
    )
    XCTAssertEqual(recordedFractions.last, 1)
  }

  func testSingleWriteIsVerifiedAndSentinelIsUntouched() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let sentinel = directory.appendingPathComponent("personal-file.txt")
    try Data("do not touch".utf8).write(to: sentinel)

    let measurement = try BenchmarkEngine.run(
      configuration: .init(
        targetDirectory: directory,
        fileSizeBytes: Int64(8 * 1_024 * 1_024),
        passes: 1,
        selection: .sequentialWrite,
        verifiesIntegrity: true
      )
    )

    XCTAssertTrue(measurement.integrityVerified)
    XCTAssertEqual(try String(contentsOf: sentinel, encoding: .utf8), "do not touch")
    XCTAssertEqual(try temporaryBenchmarkFiles(in: directory), [])
  }

  func testRequiredFreeSpaceIncludesReserve() {
    let oneGiB = Int64(1_024 * 1_024 * 1_024)
    XCTAssertEqual(
      BenchmarkEngine.requiredFreeSpace(for: oneGiB),
      oneGiB + Int64(512 * 1_024 * 1_024)
    )

    let sixteenGiB = Int64(16 * 1_024 * 1_024 * 1_024)
    XCTAssertEqual(
      BenchmarkEngine.requiredFreeSpace(for: sixteenGiB),
      sixteenGiB + sixteenGiB / 10
    )
  }

  func testCancellationStopsBeforeIOAndLeavesNoFile() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cancellation = BenchmarkCancellationToken()
    cancellation.cancel()

    XCTAssertThrowsError(
      try BenchmarkEngine.run(
        configuration: .init(
          targetDirectory: directory,
          fileSizeBytes: Int64(8 * 1_024 * 1_024),
          passes: 1,
          selection: .sequentialWrite
        ),
        cancellation: cancellation
      )
    ) { error in
      guard let benchmarkError = error as? BenchmarkError,
        case .cancelled = benchmarkError
      else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
    XCTAssertEqual(try temporaryBenchmarkFiles(in: directory), [])
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("USBBenchTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func temporaryBenchmarkFiles(in directory: URL) throws -> [String] {
    try FileManager.default
      .contentsOfDirectory(atPath: directory.path)
      .filter { $0.hasPrefix(".usbbench-") }
  }
}

private final class FractionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Double] = []

  var values: [Double] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func append(_ value: Double) {
    lock.lock()
    storage.append(value)
    lock.unlock()
  }
}
