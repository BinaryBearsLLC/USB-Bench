import Foundation

public enum SubjectKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case device
  case cable

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .device: "Device"
    case .cable: "Cable"
    }
  }
}

public enum BenchmarkProfile: String, Codable, CaseIterable, Identifiable, Sendable {
  case quick
  case complete
  case single

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .quick: "Quick"
    case .complete: "Complete"
    case .single: "Single"
    }
  }
}

public enum BenchmarkSelection: String, Codable, CaseIterable, Identifiable, Sendable {
  case all
  case sequential
  case sequentialWrite
  case sequentialRead
  case randomRead
  case randomWrite

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .all: "All tests"
    case .sequential: "Sequential read and write"
    case .sequentialWrite: "Sequential write"
    case .sequentialRead: "Sequential read"
    case .randomRead: "4K random read"
    case .randomWrite: "4K random write"
    }
  }
}

public enum BenchmarkStage: String, Codable, Sendable {
  case preparing
  case sequentialWrite
  case sequentialRead
  case verifying
  case randomRead
  case randomWrite
  case cleaning
  case finished

  public var displayName: String {
    switch self {
    case .preparing: "Preparing"
    case .sequentialWrite: "Sequential write"
    case .sequentialRead: "Sequential read"
    case .verifying: "Verifying data"
    case .randomRead: "4K random read"
    case .randomWrite: "4K random write"
    case .cleaning: "Cleaning up"
    case .finished: "Finished"
    }
  }
}

public struct BenchmarkConfiguration: Sendable {
  public var targetDirectory: URL
  public var fileSizeBytes: Int64
  public var passes: Int
  public var selection: BenchmarkSelection
  public var randomDurationSeconds: Double
  public var verifiesIntegrity: Bool

  public init(
    targetDirectory: URL,
    fileSizeBytes: Int64,
    passes: Int,
    selection: BenchmarkSelection,
    randomDurationSeconds: Double = 3,
    verifiesIntegrity: Bool = true
  ) {
    self.targetDirectory = targetDirectory
    self.fileSizeBytes = fileSizeBytes
    self.passes = passes
    self.selection = selection
    self.randomDurationSeconds = randomDurationSeconds
    self.verifiesIntegrity = verifiesIntegrity
  }
}

public struct BenchmarkProgress: Sendable {
  public var stage: BenchmarkStage
  public var fraction: Double
  public var detail: String
  public var liveValue: Double?
  public var liveUnit: String?

  public init(
    stage: BenchmarkStage,
    fraction: Double,
    detail: String,
    liveValue: Double? = nil,
    liveUnit: String? = nil
  ) {
    self.stage = stage
    self.fraction = min(max(fraction, 0), 1)
    self.detail = detail
    self.liveValue = liveValue
    self.liveUnit = liveUnit
  }
}

public struct MetricSample: Codable, Hashable, Sendable {
  public var stage: BenchmarkStage
  public var pass: Int
  public var value: Double
  public var unit: String
  public var durationSeconds: Double

  public init(
    stage: BenchmarkStage,
    pass: Int,
    value: Double,
    unit: String,
    durationSeconds: Double
  ) {
    self.stage = stage
    self.pass = pass
    self.value = value
    self.unit = unit
    self.durationSeconds = durationSeconds
  }
}

public struct BenchmarkMeasurement: Codable, Sendable {
  public var sequentialWriteMBps: Double?
  public var sequentialWriteStreamMBps: Double?
  public var sequentialWriteDurableMBps: Double?
  public var sequentialReadMBps: Double?
  public var randomReadIOPS: Double?
  public var randomWriteIOPS: Double?
  public var randomReadLatencyMS: Double?
  public var randomWriteLatencyMS: Double?
  public var writeStabilityPercent: Double?
  public var readStabilityPercent: Double?
  public var averageFlushSeconds: Double?
  public var flushPolicy: String?
  public var integrityVerified: Bool
  public var totalDurationSeconds: Double
  public var samples: [MetricSample]
  public var measurementProtocolVersion: Int?
  public var sequentialBufferBytes: Int?
  public var cachePolicy: String?
  public var preparationPolicy: String?

  public init(
    sequentialWriteMBps: Double?,
    sequentialWriteStreamMBps: Double? = nil,
    sequentialWriteDurableMBps: Double? = nil,
    sequentialReadMBps: Double?,
    randomReadIOPS: Double?,
    randomWriteIOPS: Double?,
    randomReadLatencyMS: Double?,
    randomWriteLatencyMS: Double?,
    writeStabilityPercent: Double?,
    readStabilityPercent: Double?,
    averageFlushSeconds: Double? = nil,
    flushPolicy: String? = nil,
    integrityVerified: Bool,
    totalDurationSeconds: Double,
    samples: [MetricSample],
    measurementProtocolVersion: Int? = nil,
    sequentialBufferBytes: Int? = nil,
    cachePolicy: String? = nil,
    preparationPolicy: String? = nil
  ) {
    self.sequentialWriteMBps = sequentialWriteMBps
    self.sequentialWriteStreamMBps = sequentialWriteStreamMBps
    self.sequentialWriteDurableMBps = sequentialWriteDurableMBps
    self.sequentialReadMBps = sequentialReadMBps
    self.randomReadIOPS = randomReadIOPS
    self.randomWriteIOPS = randomWriteIOPS
    self.randomReadLatencyMS = randomReadLatencyMS
    self.randomWriteLatencyMS = randomWriteLatencyMS
    self.writeStabilityPercent = writeStabilityPercent
    self.readStabilityPercent = readStabilityPercent
    self.averageFlushSeconds = averageFlushSeconds
    self.flushPolicy = flushPolicy
    self.integrityVerified = integrityVerified
    self.totalDurationSeconds = totalDurationSeconds
    self.samples = samples
    self.measurementProtocolVersion = measurementProtocolVersion
    self.sequentialBufferBytes = sequentialBufferBytes
    self.cachePolicy = cachePolicy
    self.preparationPolicy = preparationPolicy
  }
}

public struct VolumeMetadata: Codable, Hashable, Sendable {
  public var name: String
  public var path: String
  public var fileSystem: String?
  public var capacityBytes: Int64?
  public var availableBytes: Int64?
  public var isRemovable: Bool
  public var isLocal: Bool
  public var volumeUUID: String?
  public var deviceIdentifier: String?
  public var mediaName: String?
  public var busProtocol: String?
  public var isSolidState: Bool?
  public var parentWholeDisk: String?
  public var negotiatedSpeed: String?
  public var connectionKind: String?

  public init(
    name: String,
    path: String,
    fileSystem: String? = nil,
    capacityBytes: Int64? = nil,
    availableBytes: Int64? = nil,
    isRemovable: Bool = false,
    isLocal: Bool = true,
    volumeUUID: String? = nil,
    deviceIdentifier: String? = nil,
    mediaName: String? = nil,
    busProtocol: String? = nil,
    isSolidState: Bool? = nil,
    parentWholeDisk: String? = nil,
    negotiatedSpeed: String? = nil,
    connectionKind: String? = nil
  ) {
    self.name = name
    self.path = path
    self.fileSystem = fileSystem
    self.capacityBytes = capacityBytes
    self.availableBytes = availableBytes
    self.isRemovable = isRemovable
    self.isLocal = isLocal
    self.volumeUUID = volumeUUID
    self.deviceIdentifier = deviceIdentifier
    self.mediaName = mediaName
    self.busProtocol = busProtocol
    self.isSolidState = isSolidState
    self.parentWholeDisk = parentWholeDisk
    self.negotiatedSpeed = negotiatedSpeed
    self.connectionKind = connectionKind
  }

  public var stableIdentifier: String {
    volumeUUID ?? deviceIdentifier ?? path
  }
}

public struct HostMetadata: Codable, Hashable, Sendable {
  public var model: String
  public var architecture: String
  public var operatingSystem: String
  public var appVersion: String

  public init(
    model: String,
    architecture: String,
    operatingSystem: String,
    appVersion: String
  ) {
    self.model = model
    self.architecture = architecture
    self.operatingSystem = operatingSystem
    self.appVersion = appVersion
  }
}

public struct SavedBenchmark: Codable, Identifiable, Sendable {
  public var id: UUID
  public var createdAt: Date
  public var subjectKind: SubjectKind
  public var subjectName: String
  public var notes: String
  public var referenceResultID: UUID?
  public var claimedCableSpeed: String?
  public var profile: BenchmarkProfile
  public var selection: BenchmarkSelection
  public var fileSizeBytes: Int64
  public var passes: Int
  public var volume: VolumeMetadata
  public var host: HostMetadata
  public var measurement: BenchmarkMeasurement

  public init(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    subjectKind: SubjectKind,
    subjectName: String,
    notes: String,
    referenceResultID: UUID?,
    claimedCableSpeed: String?,
    profile: BenchmarkProfile,
    selection: BenchmarkSelection,
    fileSizeBytes: Int64,
    passes: Int,
    volume: VolumeMetadata,
    host: HostMetadata,
    measurement: BenchmarkMeasurement
  ) {
    self.id = id
    self.createdAt = createdAt
    self.subjectKind = subjectKind
    self.subjectName = subjectName
    self.notes = notes
    self.referenceResultID = referenceResultID
    self.claimedCableSpeed = claimedCableSpeed
    self.profile = profile
    self.selection = selection
    self.fileSizeBytes = fileSizeBytes
    self.passes = passes
    self.volume = volume
    self.host = host
    self.measurement = measurement
  }
}
