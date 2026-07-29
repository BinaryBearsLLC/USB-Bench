import Darwin
import Foundation

public enum BenchmarkError: LocalizedError {
  case targetUnavailable
  case targetNotWritable
  case insufficientSpace(required: Int64, available: Int64)
  case cannotCreateTestFile(Int32)
  case cacheBypassUnavailable(Int32)
  case cannotAllocateBuffer
  case writeFailed(Int32)
  case readFailed(Int32)
  case integrityMismatch
  case cancelled

  public var errorDescription: String? {
    switch self {
    case .targetUnavailable:
      "The selected drive is no longer available."
    case .targetNotWritable:
      "The selected folder is not writable."
    case .insufficientSpace(let required, let available):
      "Not enough free space: \(Self.format(required)) required, \(Self.format(available)) available."
    case .cannotCreateTestFile(let code):
      "Could not create the temporary file (error \(code))."
    case .cacheBypassUnavailable(let code):
      "macOS could not disable caching for this drive (error \(code)). The test stopped to avoid reporting a misleading result."
    case .cannotAllocateBuffer:
      "Not enough memory for the benchmark buffer."
    case .writeFailed(let code):
      "Write failed (error \(code))."
    case .readFailed(let code):
      "Read failed (error \(code))."
    case .integrityMismatch:
      "Data verification found an unexpected mismatch."
    case .cancelled:
      "Test cancelled."
    }
  }

  private static func format(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}

public final class BenchmarkCancellationToken: @unchecked Sendable {
  private let lock = NSLock()
  private var isCancelledStorage = false

  public init() {}

  public var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return isCancelledStorage
  }

  public func cancel() {
    lock.lock()
    isCancelledStorage = true
    lock.unlock()
  }
}

public enum BenchmarkEngine {
  public typealias ProgressHandler = @Sendable (BenchmarkProgress) -> Void
  public static let measurementProtocolVersion = 2

  public static func requiredFreeSpace(for fileSizeBytes: Int64) -> Int64 {
    fileSizeBytes + max(Int64(512 * 1_024 * 1_024), fileSizeBytes / 10)
  }

  public static func run(
    configuration: BenchmarkConfiguration,
    cancellation: BenchmarkCancellationToken = BenchmarkCancellationToken(),
    progress: @escaping ProgressHandler = { _ in }
  ) throws -> BenchmarkMeasurement {
    let overallStart = now()
    try checkCancellation(cancellation)
    try validate(configuration)

    let temporaryURL = configuration.targetDirectory
      .appendingPathComponent(".usbbench-\(UUID().uuidString).tmp", isDirectory: false)
    let descriptor = open(
      temporaryURL.path,
      O_CREAT | O_EXCL | O_NOFOLLOW | O_RDWR | O_CLOEXEC,
      S_IRUSR | S_IWUSR
    )
    guard descriptor >= 0 else {
      throw BenchmarkError.cannotCreateTestFile(errno)
    }

    defer {
      close(descriptor)
      unlink(temporaryURL.path)
    }

    guard fcntl(descriptor, F_NOCACHE, 1) == 0 else {
      throw BenchmarkError.cacheBypassUnavailable(errno)
    }
    let sequentialBufferSize = Int(min(configuration.fileSizeBytes, 8 * 1_024 * 1_024))
    guard sequentialBufferSize > 0 else {
      throw BenchmarkError.cannotAllocateBuffer
    }

    var writeStorage: UnsafeMutableRawPointer?
    var readStorage: UnsafeMutableRawPointer?
    guard posix_memalign(&writeStorage, 4_096, sequentialBufferSize) == 0,
      posix_memalign(&readStorage, 4_096, sequentialBufferSize) == 0,
      let writeBuffer = writeStorage,
      let readBuffer = readStorage
    else {
      if let writeStorage { free(writeStorage) }
      if let readStorage { free(readStorage) }
      throw BenchmarkError.cannotAllocateBuffer
    }

    defer {
      free(writeBuffer)
      free(readBuffer)
    }

    arc4random_buf(writeBuffer, sequentialBufferSize)
    memset(readBuffer, 0, sequentialBufferSize)

    var samples: [MetricSample] = []
    var integrityVerified = false
    var fileContainsPattern = false
    var writeStreamValues: [Double] = []
    var writeFlushDurations: [Double] = []
    var appliedFlushPolicy: String?
    let runsSequentialWrite =
      configuration.selection == .all
      || configuration.selection == .sequential
      || configuration.selection == .sequentialWrite
    let runsSequentialRead =
      configuration.selection == .all
      || configuration.selection == .sequential
      || configuration.selection == .sequentialRead
    let runsRandomRead =
      configuration.selection == .all
      || configuration.selection == .randomRead
    let runsRandomWrite =
      configuration.selection == .all
      || configuration.selection == .randomWrite
    var mutableProgressStages: [BenchmarkStage] = [.preparing]
    if runsSequentialWrite { mutableProgressStages.append(.sequentialWrite) }
    if runsSequentialRead { mutableProgressStages.append(.sequentialRead) }
    if runsRandomRead { mutableProgressStages.append(.randomRead) }
    if runsRandomWrite { mutableProgressStages.append(.randomWrite) }
    if configuration.verifiesIntegrity { mutableProgressStages.append(.verifying) }
    mutableProgressStages.append(.cleaning)
    let progressStages = mutableProgressStages
    let report: ProgressHandler = { update in
      if update.stage == .finished {
        progress(update)
        return
      }
      guard let index = progressStages.firstIndex(of: update.stage) else {
        progress(update)
        return
      }
      var scaled = update
      let local = min(max(update.fraction, 0), 1)
      scaled.fraction = (Double(index) + local) / Double(progressStages.count)
      progress(scaled)
    }

    func ensurePatternFile() throws {
      guard !fileContainsPattern else { return }
      report(
        .init(
          stage: .preparing,
          fraction: 0,
          detail: "Preparing the temporary file; this phase is not measured."
        ))
      _ = try writeSequential(
        descriptor: descriptor,
        fileSize: configuration.fileSizeBytes,
        buffer: writeBuffer,
        bufferSize: sequentialBufferSize,
        cancellation: cancellation,
        stage: .preparing,
        pass: 0,
        totalPasses: 1,
        progress: report,
        reportsLiveSpeed: false
      )
      let flush = try flushDescriptor(descriptor)
      appliedFlushPolicy = flush.policy
      fileContainsPattern = true
    }

    try ensurePatternFile()

    if runsSequentialWrite {
      for pass in 1...configuration.passes {
        try checkCancellation(cancellation)
        let streamDuration = try writeSequential(
          descriptor: descriptor,
          fileSize: configuration.fileSizeBytes,
          buffer: writeBuffer,
          bufferSize: sequentialBufferSize,
          cancellation: cancellation,
          stage: .sequentialWrite,
          pass: pass,
          totalPasses: configuration.passes,
          progress: report,
          reportsLiveSpeed: true
        )
        let flush = try flushDescriptor(descriptor)
        appliedFlushPolicy = flush.policy
        let duration = max(streamDuration + flush.duration, 0.000_001)
        let speed = Double(configuration.fileSizeBytes) / duration / 1_000_000
        let streamSpeed =
          Double(configuration.fileSizeBytes)
          / max(streamDuration, 0.000_001)
          / 1_000_000
        writeStreamValues.append(streamSpeed)
        writeFlushDurations.append(flush.duration)
        samples.append(
          .init(
            stage: .sequentialWrite,
            pass: pass,
            value: speed,
            unit: "MB/s",
            durationSeconds: duration
          ))
      }
      fileContainsPattern = true
    }

    if runsSequentialRead {
      for pass in 1...configuration.passes {
        try checkCancellation(cancellation)
        let started = now()
        try readSequential(
          descriptor: descriptor,
          fileSize: configuration.fileSizeBytes,
          readBuffer: readBuffer,
          bufferSize: sequentialBufferSize,
          cancellation: cancellation,
          pass: pass,
          totalPasses: configuration.passes,
          progress: report
        )
        let duration = max(now() - started, 0.000_001)
        let speed = Double(configuration.fileSizeBytes) / duration / 1_000_000
        samples.append(
          .init(
            stage: .sequentialRead,
            pass: pass,
            value: speed,
            unit: "MB/s",
            durationSeconds: duration
          ))
      }
    }

    var randomReadLatency: Double?
    var randomWriteLatency: Double?

    if runsRandomRead {
      let result = try randomIO(
        descriptor: descriptor,
        fileSize: configuration.fileSizeBytes,
        buffer: readBuffer,
        isWrite: false,
        durationLimit: configuration.randomDurationSeconds,
        cancellation: cancellation,
        progress: report
      )
      randomReadLatency = result.latencyMS
      samples.append(
        .init(
          stage: .randomRead,
          pass: 1,
          value: result.iops,
          unit: "IOPS",
          durationSeconds: result.duration
        ))
    }

    if runsRandomWrite {
      let result = try randomIO(
        descriptor: descriptor,
        fileSize: configuration.fileSizeBytes,
        buffer: writeBuffer,
        patternBufferSize: sequentialBufferSize,
        isWrite: true,
        durationLimit: configuration.randomDurationSeconds,
        cancellation: cancellation,
        progress: report
      )
      _ = try flushDescriptor(descriptor)
      randomWriteLatency = result.latencyMS
      samples.append(
        .init(
          stage: .randomWrite,
          pass: 1,
          value: result.iops,
          unit: "IOPS",
          durationSeconds: result.duration
        ))
    }

    if configuration.verifiesIntegrity {
      try verifySequential(
        descriptor: descriptor,
        fileSize: configuration.fileSizeBytes,
        expectedBuffer: writeBuffer,
        readBuffer: readBuffer,
        bufferSize: sequentialBufferSize,
        cancellation: cancellation,
        progress: report
      )
      integrityVerified = true
    }

    report(.init(stage: .cleaning, fraction: 0.5, detail: "Removing the temporary file."))

    let readValues =
      samples
      .filter { $0.stage == .sequentialRead }
      .map(\.value)
    let randomReadIOPS = samples.first { $0.stage == .randomRead }?.value
    let randomWriteIOPS = samples.first { $0.stage == .randomWrite }?.value

    report(.init(stage: .finished, fraction: 1, detail: "Test complete."))

    let writeSamples = samples.filter { $0.stage == .sequentialWrite }
    let readSamples = samples.filter { $0.stage == .sequentialRead }
    let canonicalWrite = throughput(
      bytesPerPass: configuration.fileSizeBytes,
      durations: writeSamples.map(\.durationSeconds)
    )
    let streamWrite = throughput(
      bytesPerPass: configuration.fileSizeBytes,
      durations: writeStreamValues.enumerated().map { index, speed in
        guard speed > 0 else { return 0 }
        return Double(configuration.fileSizeBytes) / speed / 1_000_000
      }
    )
    let canonicalRead = throughput(
      bytesPerPass: configuration.fileSizeBytes,
      durations: readSamples.map(\.durationSeconds)
    )

    return BenchmarkMeasurement(
      sequentialWriteMBps: streamWrite,
      sequentialWriteStreamMBps: streamWrite,
      sequentialWriteDurableMBps: canonicalWrite,
      sequentialReadMBps: canonicalRead,
      randomReadIOPS: randomReadIOPS,
      randomWriteIOPS: randomWriteIOPS,
      randomReadLatencyMS: randomReadLatency,
      randomWriteLatencyMS: randomWriteLatency,
      writeStabilityPercent: stability(writeStreamValues),
      readStabilityPercent: stability(readValues),
      averageFlushSeconds: average(writeFlushDurations),
      flushPolicy: appliedFlushPolicy,
      integrityVerified: integrityVerified,
      totalDurationSeconds: now() - overallStart,
      samples: samples,
      measurementProtocolVersion: measurementProtocolVersion,
      sequentialBufferBytes: sequentialBufferSize,
      cachePolicy: "F_NOCACHE",
      preparationPolicy: "warm-up fill excluded"
    )
  }

  private static func validate(_ configuration: BenchmarkConfiguration) throws {
    var isDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: configuration.targetDirectory.path,
        isDirectory: &isDirectory
      ), isDirectory.boolValue
    else {
      throw BenchmarkError.targetUnavailable
    }
    guard FileManager.default.isWritableFile(atPath: configuration.targetDirectory.path) else {
      throw BenchmarkError.targetNotWritable
    }
    let attributes = try FileManager.default.attributesOfFileSystem(
      forPath: configuration.targetDirectory.path
    )
    let available = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    let required = requiredFreeSpace(for: configuration.fileSizeBytes)
    guard available >= required else {
      throw BenchmarkError.insufficientSpace(required: required, available: available)
    }
    guard configuration.fileSizeBytes >= 4_096, configuration.passes > 0 else {
      throw BenchmarkError.targetUnavailable
    }
  }

  @discardableResult
  private static func writeSequential(
    descriptor: Int32,
    fileSize: Int64,
    buffer: UnsafeMutableRawPointer,
    bufferSize: Int,
    cancellation: BenchmarkCancellationToken,
    stage: BenchmarkStage,
    pass: Int,
    totalPasses: Int,
    progress: ProgressHandler,
    reportsLiveSpeed: Bool
  ) throws -> Double {
    var offset: Int64 = 0
    let started = now()
    var lastReportedFraction = -1.0

    while offset < fileSize {
      try checkCancellation(cancellation)
      let count = Int(min(Int64(bufferSize), fileSize - offset))
      var written = 0
      while written < count {
        let result = pwrite(
          descriptor,
          buffer.advanced(by: written),
          count - written,
          off_t(offset + Int64(written))
        )
        guard result > 0 else {
          throw BenchmarkError.writeFailed(errno)
        }
        written += result
      }
      offset += Int64(count)

      let localFraction = Double(offset) / Double(fileSize)
      if localFraction - lastReportedFraction >= 0.025 || offset == fileSize {
        lastReportedFraction = localFraction
        let elapsed = max(now() - started, 0.000_001)
        let speed = reportsLiveSpeed ? Double(offset) / elapsed / 1_000_000 : nil
        let overall =
          pass > 0
          ? (Double(pass - 1) + localFraction) / Double(max(totalPasses, 1))
          : localFraction
        progress(
          .init(
            stage: stage,
            fraction: overall,
            detail: pass > 0 ? "Pass \(pass) of \(totalPasses)" : "Preparing data",
            liveValue: speed,
            liveUnit: speed == nil ? nil : "MB/s"
          ))
      }
    }
    return now() - started
  }

  private static func readSequential(
    descriptor: Int32,
    fileSize: Int64,
    readBuffer: UnsafeMutableRawPointer,
    bufferSize: Int,
    cancellation: BenchmarkCancellationToken,
    pass: Int,
    totalPasses: Int,
    progress: ProgressHandler
  ) throws {
    var offset: Int64 = 0
    let started = now()
    var lastReportedFraction = -1.0

    while offset < fileSize {
      try checkCancellation(cancellation)
      let count = Int(min(Int64(bufferSize), fileSize - offset))
      var readCount = 0
      while readCount < count {
        let result = pread(
          descriptor,
          readBuffer.advanced(by: readCount),
          count - readCount,
          off_t(offset + Int64(readCount))
        )
        guard result > 0 else {
          throw BenchmarkError.readFailed(errno)
        }
        readCount += result
      }
      offset += Int64(count)

      let localFraction = Double(offset) / Double(fileSize)
      if localFraction - lastReportedFraction >= 0.025 || offset == fileSize {
        lastReportedFraction = localFraction
        let elapsed = max(now() - started, 0.000_001)
        progress(
          .init(
            stage: .sequentialRead,
            fraction: (Double(pass - 1) + localFraction) / Double(max(totalPasses, 1)),
            detail: "Pass \(pass) of \(totalPasses)",
            liveValue: Double(offset) / elapsed / 1_000_000,
            liveUnit: "MB/s"
          ))
      }
    }
  }

  private static func verifySequential(
    descriptor: Int32,
    fileSize: Int64,
    expectedBuffer: UnsafeMutableRawPointer,
    readBuffer: UnsafeMutableRawPointer,
    bufferSize: Int,
    cancellation: BenchmarkCancellationToken,
    progress: ProgressHandler
  ) throws {
    var offset: Int64 = 0
    var lastReportedFraction = -1.0

    while offset < fileSize {
      try checkCancellation(cancellation)
      let count = Int(min(Int64(bufferSize), fileSize - offset))
      var readCount = 0
      while readCount < count {
        let result = pread(
          descriptor,
          readBuffer.advanced(by: readCount),
          count - readCount,
          off_t(offset + Int64(readCount))
        )
        guard result > 0 else {
          throw BenchmarkError.readFailed(errno)
        }
        readCount += result
      }
      if memcmp(expectedBuffer, readBuffer, count) != 0 {
        throw BenchmarkError.integrityMismatch
      }
      offset += Int64(count)

      let fraction = Double(offset) / Double(fileSize)
      if fraction - lastReportedFraction >= 0.04 || offset == fileSize {
        lastReportedFraction = fraction
        progress(
          .init(
            stage: .verifying,
            fraction: fraction,
            detail: "Checking data outside the timed measurement."
          ))
      }
    }
  }

  private static func randomIO(
    descriptor: Int32,
    fileSize: Int64,
    buffer: UnsafeMutableRawPointer,
    patternBufferSize: Int = 4_096,
    isWrite: Bool,
    durationLimit: Double,
    cancellation: BenchmarkCancellationToken,
    progress: ProgressHandler
  ) throws -> (iops: Double, latencyMS: Double, duration: Double) {
    let blockSize = 4_096
    let blockCount = max(UInt64(fileSize / Int64(blockSize)), 1)
    let stage: BenchmarkStage = isWrite ? .randomWrite : .randomRead
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    var operations = 0
    let started = now()
    let targetDuration = max(durationLimit, 0.05)
    var lastProgress = -1.0

    while now() - started < targetDuration {
      try checkCancellation(cancellation)
      state ^= state << 13
      state ^= state >> 7
      state ^= state << 17
      let block = state % blockCount
      let offset = off_t(block * UInt64(blockSize))

      let result: Int
      if isWrite {
        let patternOffset = Int(offset) % max(patternBufferSize, blockSize)
        result = pwrite(
          descriptor,
          buffer.advanced(by: patternOffset),
          blockSize,
          offset
        )
      } else {
        result = pread(descriptor, buffer, blockSize, offset)
      }
      guard result == blockSize else {
        if isWrite {
          throw BenchmarkError.writeFailed(errno)
        } else {
          throw BenchmarkError.readFailed(errno)
        }
      }
      operations += 1

      let elapsed = now() - started
      let fraction = min(elapsed / targetDuration, 1)
      if fraction - lastProgress >= 0.04 {
        lastProgress = fraction
        progress(
          .init(
            stage: stage,
            fraction: fraction,
            detail: "4K blocks, queue depth 1",
            liveValue: Double(operations) / max(elapsed, 0.000_001),
            liveUnit: "IOPS"
          ))
      }
    }

    let duration = max(now() - started, 0.000_001)
    let iops = Double(operations) / duration
    return (
      iops: iops,
      latencyMS: duration * 1_000 / Double(max(operations, 1)),
      duration: duration
    )
  }

  private static func checkCancellation(_ token: BenchmarkCancellationToken) throws {
    if token.isCancelled {
      throw BenchmarkError.cancelled
    }
  }

  private static func flushDescriptor(_ descriptor: Int32) throws -> (
    duration: Double, policy: String
  ) {
    let started = now()
    if fcntl(descriptor, F_FULLFSYNC) == 0 {
      return (now() - started, "F_FULLFSYNC")
    }
    guard fsync(descriptor) == 0 else {
      throw BenchmarkError.writeFailed(errno)
    }
    return (now() - started, "fsync")
  }

  private static func now() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
  }

  private static func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
  }

  private static func throughput(
    bytesPerPass: Int64,
    durations: [Double]
  ) -> Double? {
    guard !durations.isEmpty else { return nil }
    let totalDuration = durations.reduce(0, +)
    guard totalDuration > 0 else { return nil }
    return Double(bytesPerPass) * Double(durations.count) / totalDuration / 1_000_000
  }

  private static func stability(_ values: [Double]) -> Double? {
    guard values.count > 1, let mean = average(values), mean > 0 else {
      return values.isEmpty ? nil : 100
    }
    let variance =
      values
      .map { pow($0 - mean, 2) }
      .reduce(0, +) / Double(values.count)
    let relativeDeviation = sqrt(variance) / mean * 100
    return min(max(100 - relativeDeviation, 0), 100)
  }
}
