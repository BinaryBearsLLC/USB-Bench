import Foundation
import XCTest

@testable import USBBenchCore

final class ResultStoreTests: XCTestCase {
  func testRoundTripTrashRestoreAndPermanentDelete() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("USBBenchStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try ResultStore(databaseURL: directory.appendingPathComponent("results.sqlite3"))
    let result = fixture()
    try store.save(result)

    let loaded = try store.loadAll()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.id, result.id)
    XCTAssertEqual(loaded.first?.subjectName, "SSD riferimento")
    XCTAssertEqual(loaded.first?.volume.mediaName, "Fixture SSD")
    XCTAssertEqual(
      loaded.first?.measurement.sequentialReadMBps ?? 0,
      934.2,
      accuracy: 0.001
    )

    try store.trash(id: result.id)
    XCTAssertTrue(try store.loadAll().isEmpty)
    XCTAssertEqual(try store.loadTrashed().map(\.id), [result.id])

    try store.restore(id: result.id)
    XCTAssertEqual(try store.loadAll().map(\.id), [result.id])
    XCTAssertTrue(try store.loadTrashed().isEmpty)

    try store.trash(id: result.id)
    try store.deletePermanently(id: result.id)
    XCTAssertTrue(try store.loadAll().isEmpty)
    XCTAssertTrue(try store.loadTrashed().isEmpty)
  }

  private func fixture() -> SavedBenchmark {
    SavedBenchmark(
      subjectKind: .device,
      subjectName: "SSD riferimento",
      notes: "Enclosure USB 10 Gb/s",
      referenceResultID: nil,
      claimedCableSpeed: nil,
      profile: .complete,
      selection: .all,
      fileSizeBytes: 2 * 1_024 * 1_024 * 1_024,
      passes: 3,
      volume: .init(
        name: "TEST",
        path: "/Volumes/TEST",
        fileSystem: "apfs",
        capacityBytes: 1_000_000_000_000,
        availableBytes: 700_000_000_000,
        isRemovable: true,
        volumeUUID: "fixture-volume",
        deviceIdentifier: "disk9s1",
        mediaName: "Fixture SSD",
        busProtocol: "USB",
        isSolidState: true
      ),
      host: .init(
        model: "Mac17,4",
        architecture: "arm64",
        operatingSystem: "macOS",
        appVersion: "1.0.0"
      ),
      measurement: .init(
        sequentialWriteMBps: 812.4,
        sequentialReadMBps: 934.2,
        randomReadIOPS: 8_412,
        randomWriteIOPS: 7_318,
        randomReadLatencyMS: 0.12,
        randomWriteLatencyMS: 0.14,
        writeStabilityPercent: 98.2,
        readStabilityPercent: 99.1,
        integrityVerified: true,
        totalDurationSeconds: 32,
        samples: []
      )
    )
  }
}
