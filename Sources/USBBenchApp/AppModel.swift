import AppKit
import Foundation
import SwiftUI
import USBBenchCore

enum SidebarSection: String, CaseIterable, Identifiable {
  case newTest
  case results
  case comparison
  case information
  case settings

  var id: String { rawValue }

  func title(_ text: AppText) -> String {
    switch self {
    case .newTest: text("Nuovo test", "New test")
    case .results: text("Risultati", "Results")
    case .comparison: text("Confronto", "Comparison")
    case .information: text("Informazioni", "Information")
    case .settings: text("Impostazioni", "Settings")
    }
  }

  var symbol: String {
    switch self {
    case .newTest: "gauge.with.dots.needle.50percent"
    case .results: "clock.arrow.trianglehead.counterclockwise.rotate.90"
    case .comparison: "chart.bar.xaxis"
    case .information: "info.circle"
    case .settings: "gearshape"
    }
  }
}

struct BenchmarkSizeOption: Identifiable, Hashable {
  let bytes: Int64
  let label: String

  var id: Int64 { bytes }

  static let options: [BenchmarkSizeOption] = [
    .init(bytes: 512 * 1_024 * 1_024, label: "512 MB"),
    .init(bytes: 2 * 1_024 * 1_024 * 1_024, label: "2 GB"),
    .init(bytes: 8 * 1_024 * 1_024 * 1_024, label: "8 GB"),
    .init(bytes: 16 * 1_024 * 1_024 * 1_024, label: "16 GB"),
  ]

  func localizedDetail(_ text: AppText) -> String {
    switch bytes {
    case 512 * 1_024 * 1_024:
      text("rapido", "fast")
    case 2 * 1_024 * 1_024 * 1_024:
      text("bilanciato", "balanced")
    case 8 * 1_024 * 1_024 * 1_024:
      text("cache e stabilità", "cache and stability")
    default:
      text("sostenuto", "sustained")
    }
  }
}

struct UserAlert: Identifiable {
  let id = UUID()
  let title: String
  let message: String
}

@MainActor
final class AppModel: ObservableObject {
  @Published var language: AppLanguage {
    didSet {
      UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }
  }
  @Published var appearance: AppAppearance {
    didSet {
      UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
    }
  }
  @Published var section: SidebarSection = .newTest
  @Published var subjectKind: SubjectKind = .device
  @Published var subjectName = ""
  @Published var notes = ""
  @Published var referenceResultID = ""
  @Published var claimedCableSpeed: CableSpeedClaim = .unspecified

  @Published var selectedFolder: URL?
  @Published var selectedVolume: VolumeMetadata?
  @Published var isInspectingVolume = false

  @Published var profile: BenchmarkProfile = .quick
  @Published var singleSelection: BenchmarkSelection = .sequentialWrite
  @Published var selectedSizeBytes = BenchmarkSizeOption.options[1].bytes

  @Published var isRunning = false
  @Published var progress = BenchmarkProgress(
    stage: .preparing,
    fraction: 0,
    detail: "Ready"
  )
  @Published var currentResult: SavedBenchmark?
  @Published var isCurrentResultSaved = false

  @Published var savedResults: [SavedBenchmark] = []
  @Published var trashedResults: [SavedBenchmark] = []
  @Published var comparisonFilter: ResultKindFilter = .all
  @Published var comparisonAID: UUID?
  @Published var comparisonBID: UUID?
  @Published var alert: UserAlert?

  private var store: ResultStore?
  private var cancellation: BenchmarkCancellationToken?
  private var benchmarkTask: Task<Void, Never>?
  private var activity: NSObjectProtocol?

  init() {
    language =
      AppLanguage(
        rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? ""
      ) ?? .english
    appearance =
      AppAppearance(
        rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? ""
      ) ?? .automatic
    do {
      store = try ResultStore()
      reloadResults()
    } catch {
      alert = .init(
        title: text("Database non disponibile", "Database unavailable"),
        message: error.localizedDescription
      )
    }
  }

  var text: AppText {
    AppText(language: language)
  }

  var deviceReferences: [SavedBenchmark] {
    savedResults.filter { $0.subjectKind == .device }
  }

  var comparisonResults: [SavedBenchmark] {
    savedResults.filter { comparisonFilter.matches($0.subjectKind) }
  }

  var effectiveSelection: BenchmarkSelection {
    switch profile {
    case .quick: .sequential
    case .complete: .all
    case .single: singleSelection
    }
  }

  var configuredPasses: Int {
    switch profile {
    case .quick: 2
    case .complete: 3
    case .single: 1
    }
  }

  var randomDuration: Double {
    switch profile {
    case .quick: 1.5
    case .complete: 5
    case .single: 3
    }
  }

  var canStart: Bool {
    selectedFolder != nil
      && selectedVolume != nil
      && !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isRunning
      && spacePreflight?.isEnough != false
  }

  var requiredFreeSpace: Int64 {
    BenchmarkEngine.requiredFreeSpace(for: selectedSizeBytes)
  }

  var spacePreflight: (available: Int64, required: Int64, isEnough: Bool)? {
    guard let available = selectedVolume?.availableBytes else { return nil }
    let required = requiredFreeSpace
    return (available, required, available >= required)
  }

  var practicalLinkCeilingMBps: Double? {
    guard let speed = selectedVolume?.negotiatedSpeed,
      let number = speed.split(separator: " ").first.flatMap({ Double($0) })
    else { return nil }
    return speed.contains("Gb/s")
      ? number * 1_000 / 8 * 0.8
      : speed.contains("Mb/s") ? number / 8 * 0.75 : nil
  }

  var negotiatedLinkGbps: Double? {
    guard let speed = selectedVolume?.negotiatedSpeed,
      let number = speed.split(separator: " ").first.flatMap({ Double($0) })
    else { return nil }
    if speed.contains("Gb/s") { return number }
    if speed.contains("Mb/s") { return number / 1_000 }
    return nil
  }

  var cableVerificationWarning: String? {
    guard subjectKind == .cable,
      let claimed = claimedCableSpeed.nominalGbps,
      let negotiated = negotiatedLinkGbps,
      claimed > negotiated
    else { return nil }
    return text(
      "Il cavo è dichiarato \(claimed.formatted()) Gb/s, ma questo collegamento ne verifica soltanto \(negotiated.formatted()) Gb/s.",
      "The cable is rated for \(claimed.formatted()) Gb/s, but this connection can verify only \(negotiated.formatted()) Gb/s."
    )
  }

  var startDisabledReason: String? {
    if selectedFolder == nil {
      return text("Scegli prima l’unità di test.", "Choose a test drive first.")
    }
    if subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return text("Inserisci un nome per il test.", "Enter a name for the test.")
    }
    if spacePreflight?.isEnough == false {
      return text("Lo spazio libero non è sufficiente.", "There is not enough free space.")
    }
    return nil
  }

  var estimatedWriteBytes: Int64 {
    let selection = effectiveSelection
    let sequentialWrites =
      selection == .all
        || selection == .sequential
        || selection == .sequentialWrite
      ? configuredPasses
      : 0
    let preparationWrite = 1
    return selectedSizeBytes * Int64(sequentialWrites + preparationWrite)
  }

  func setProfile(_ newProfile: BenchmarkProfile) {
    profile = newProfile
    switch newProfile {
    case .quick:
      selectedSizeBytes = BenchmarkSizeOption.options[1].bytes
    case .complete:
      selectedSizeBytes = BenchmarkSizeOption.options[2].bytes
    case .single:
      if selectedSizeBytes > BenchmarkSizeOption.options[2].bytes {
        selectedSizeBytes = BenchmarkSizeOption.options[1].bytes
      }
    }
  }

  func chooseTarget() {
    let panel = NSOpenPanel()
    panel.title = text(
      "Scegli l’unità o una cartella di test",
      "Choose a drive or test folder"
    )
    panel.message = text(
      "USB Bench creerà e rimuoverà un solo file temporaneo nella posizione scelta.",
      "USB Bench will create and remove one temporary file in the selected location."
    )
    panel.prompt = text("Usa questa posizione", "Use this location")
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    if FileManager.default.fileExists(atPath: "/Volumes") {
      panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
    }

    guard panel.runModal() == .OK, let url = panel.url else { return }
    selectedFolder = url
    selectedVolume = nil
    currentResult = nil
    isInspectingVolume = true

    Task {
      let metadata = await Task.detached(priority: .userInitiated) {
        SystemInspector.inspectVolume(at: url)
      }.value
      selectedVolume = metadata
      isInspectingVolume = false
    }
  }

  func startTest() {
    guard let target = selectedFolder, selectedVolume != nil else {
      alert = .init(
        title: text("Seleziona un’unità", "Choose a drive"),
        message: text(
          "Scegli prima l’unità o la cartella sulla quale creare il file temporaneo.",
          "Choose the drive or folder where the temporary file will be created."
        )
      )
      return
    }
    let cleanName = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else {
      alert = .init(
        title: text("Dai un nome al test", "Name the test"),
        message: text(
          "Il nome serve per ritrovare e confrontare il risultato.",
          "A name lets you find and compare the result later."
        )
      )
      return
    }

    let previouslyNegotiatedSpeed = selectedVolume?.negotiatedSpeed
    let volume = SystemInspector.inspectVolume(at: target)
    selectedVolume = volume
    if let before = previouslyNegotiatedSpeed,
      let now = volume.negotiatedSpeed,
      before != now
    {
      alert = .init(
        title: text("Collegamento USB cambiato", "USB connection changed"),
        message: text(
          "La velocità negoziata era \(before) e ora è \(now). Ho aggiornato il controllo preliminare: verifica cavo, porta o hub e premi nuovamente Avvia.",
          "The negotiated speed was \(before) and is now \(now). The preflight has been updated; check the cable, port or hub, then press Start again."
        )
      )
      return
    }
    if let available = volume.availableBytes, available < requiredFreeSpace {
      alert = .init(
        title: text("Spazio insufficiente", "Not enough free space"),
        message: text(
          "Servono \(Formatters.bytes(requiredFreeSpace)); sono disponibili \(Formatters.bytes(available)).",
          "\(Formatters.bytes(requiredFreeSpace)) is required; \(Formatters.bytes(available)) is available."
        )
      )
      return
    }

    let configuration = BenchmarkConfiguration(
      targetDirectory: target,
      fileSizeBytes: selectedSizeBytes,
      passes: configuredPasses,
      selection: effectiveSelection,
      randomDurationSeconds: randomDuration,
      verifiesIntegrity: true
    )
    let token = BenchmarkCancellationToken()
    cancellation = token
    currentResult = nil
    isCurrentResultSaved = false
    isRunning = true
    progress = .init(
      stage: .preparing,
      fraction: 0,
      detail: "Rechecking free space, permissions, and the USB connection…"
    )
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .idleSystemSleepDisabled],
      reason: "Benchmark unità esterna in corso"
    )

    let resultKind = subjectKind
    let resultNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    let resultProfile = profile
    let resultSelection = effectiveSelection
    let resultReferenceID = UUID(uuidString: referenceResultID)
    let resultClaimedSpeed =
      resultKind == .cable && claimedCableSpeed != .unspecified
      ? claimedCableSpeed.rawValue
      : nil
    let resultSize = selectedSizeBytes
    let resultPasses = configuredPasses

    benchmarkTask = Task {
      do {
        let measurement = try await Task.detached(priority: .userInitiated) { [weak self] in
          try BenchmarkEngine.run(
            configuration: configuration,
            cancellation: token
          ) { update in
            DispatchQueue.main.async {
              self?.progress = update
            }
          }
        }.value

        currentResult = SavedBenchmark(
          subjectKind: resultKind,
          subjectName: cleanName,
          notes: resultNotes,
          referenceResultID: resultReferenceID,
          claimedCableSpeed: resultClaimedSpeed,
          profile: resultProfile,
          selection: resultSelection,
          fileSizeBytes: resultSize,
          passes: resultPasses,
          volume: volume,
          host: SystemInspector.hostMetadata(),
          measurement: measurement
        )
        finishRun()
      } catch {
        finishRun()
        if let benchmarkError = error as? BenchmarkError,
          case .cancelled = benchmarkError
        {
          progress = .init(
            stage: .cleaning,
            fraction: 0,
            detail: "Test cancelled and temporary file removed."
          )
        } else {
          alert = .init(
            title: text("Test non completato", "Test not completed"),
            message: localizedError(error)
          )
        }
      }
    }
  }

  func cancelTest() {
    cancellation?.cancel()
    progress = .init(
      stage: progress.stage,
      fraction: progress.fraction,
      detail: "Stopping safely after the current operation…"
    )
  }

  func saveCurrentResult() {
    guard let result = currentResult, let store else { return }
    do {
      try store.save(result)
      isCurrentResultSaved = true
      reloadResults()
    } catch {
      alert = .init(
        title: text("Salvataggio non riuscito", "Could not save result"),
        message: error.localizedDescription
      )
    }
  }

  func trashResult(_ result: SavedBenchmark) {
    guard let store else { return }
    do {
      try store.trash(id: result.id)
      reloadResults()
    } catch {
      alert = .init(
        title: text("Spostamento non riuscito", "Could not move result"),
        message: error.localizedDescription
      )
    }
  }

  func restoreResult(_ result: SavedBenchmark) {
    guard let store else { return }
    do {
      try store.restore(id: result.id)
      reloadResults()
    } catch {
      alert = .init(
        title: text("Ripristino non riuscito", "Could not restore result"),
        message: error.localizedDescription
      )
    }
  }

  func deleteResultPermanently(_ result: SavedBenchmark) {
    guard let store else { return }
    do {
      try store.deletePermanently(id: result.id)
      reloadResults()
    } catch {
      alert = .init(
        title: text("Eliminazione non riuscita", "Could not delete result"),
        message: error.localizedDescription
      )
    }
  }

  func prepareComparison(with result: SavedBenchmark) {
    comparisonFilter = ResultKindFilter(subjectKind: result.subjectKind)
    comparisonAID = result.id
    comparisonBID = comparisonResults.first(where: { $0.id != result.id })?.id
    section = .comparison
  }

  func normalizeComparisonSelection() {
    let results = comparisonResults
    if comparisonAID.flatMap({ id in results.first { $0.id == id } }) == nil {
      comparisonAID = results.first?.id
    }
    if comparisonBID.flatMap({ id in results.first { $0.id == id } }) == nil
      || comparisonBID == comparisonAID
    {
      comparisonBID = results.first { $0.id != comparisonAID }?.id
    }
  }

  func exportCSV(_ results: [SavedBenchmark]) {
    guard !results.isEmpty else { return }
    let panel = NSSavePanel()
    panel.title = text("Esporta risultati", "Export results")
    panel.nameFieldStringValue = "USB-Bench-risultati.csv"
    panel.allowedContentTypes = [.commaSeparatedText]
    guard panel.runModal() == .OK, let url = panel.url else { return }

    let header = [
      text("Data", "Date"),
      text("Tipo", "Type"),
      text("Nome", "Name"),
      text("Note", "Notes"),
      "Volume",
      text("Nome hardware", "Hardware name"),
      text("Protocollo", "Protocol"),
      text("Filesystem", "File system"),
      text("Identificatore dispositivo", "Device identifier"),
      text("Collegamento", "Connection"),
      text("Velocità negoziata", "Negotiated speed"),
      text("Profilo", "Profile"),
      text("Dimensione byte", "Size bytes"),
      text("Scrittura MB/s", "Write MB/s"),
      text("Scrittura persistita MB/s", "Durable write MB/s"),
      text("Flush secondi", "Flush seconds"),
      text("Lettura MB/s", "Read MB/s"),
      "Random read IOPS",
      "Random write IOPS",
      text("Stabilità scrittura %", "Write stability %"),
      text("Stabilità lettura %", "Read stability %"),
      text("Protocollo misura", "Measurement protocol"),
    ].joined(separator: ",")
    let rows = results.map { result in
      [
        ISO8601DateFormatter().string(from: result.createdAt),
        text.subject(result.subjectKind),
        result.subjectName,
        result.notes,
        result.volume.name,
        result.volume.mediaName ?? "",
        result.volume.busProtocol ?? "",
        result.volume.fileSystem ?? "",
        result.volume.deviceIdentifier ?? "",
        text.connection(result.volume.connectionKind) ?? "",
        result.volume.negotiatedSpeed ?? "",
        text.profile(result.profile),
        "\(result.fileSizeBytes)",
        number(result.measurement.sequentialWriteMBps),
        number(result.measurement.sequentialWriteDurableMBps),
        number(result.measurement.averageFlushSeconds),
        number(result.measurement.sequentialReadMBps),
        number(result.measurement.randomReadIOPS),
        number(result.measurement.randomWriteIOPS),
        number(result.measurement.writeStabilityPercent),
        number(result.measurement.readStabilityPercent),
        result.measurement.measurementProtocolVersion.map(String.init) ?? "1",
      ]
      .map(csvEscape)
      .joined(separator: ",")
    }

    do {
      try ([header] + rows).joined(separator: "\n").write(
        to: url,
        atomically: true,
        encoding: .utf8
      )
    } catch {
      alert = .init(
        title: text("Esportazione non riuscita", "Export failed"),
        message: error.localizedDescription
      )
    }
  }

  private func reloadResults() {
    guard let store else { return }
    do {
      savedResults = try store.loadAll()
      trashedResults = try store.loadTrashed()
      normalizeComparisonSelection()
    } catch {
      alert = .init(
        title: text("Lettura risultati non riuscita", "Could not read results"),
        message: error.localizedDescription
      )
    }
  }

  private func finishRun() {
    isRunning = false
    cancellation = nil
    benchmarkTask = nil
    if let activity {
      ProcessInfo.processInfo.endActivity(activity)
      self.activity = nil
    }
  }

  private func number(_ value: Double?) -> String {
    value.map { String(format: "%.2f", $0) } ?? ""
  }

  private func csvEscape(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private func localizedError(_ error: Error) -> String {
    guard language == .english, let benchmarkError = error as? BenchmarkError else {
      return error.localizedDescription
    }
    return switch benchmarkError {
    case .targetUnavailable:
      "The selected drive is no longer available."
    case .targetNotWritable:
      "The selected folder is not writable."
    case .insufficientSpace(let required, let available):
      "\(Formatters.bytes(required)) is required; \(Formatters.bytes(available)) is available."
    case .cannotCreateTestFile(let code):
      "Could not create the temporary file (error \(code))."
    case .cacheBypassUnavailable(let code):
      "macOS could not disable its file cache for this drive (error \(code)). The test was stopped to avoid a misleading result."
    case .cannotAllocateBuffer:
      "Not enough memory for the test buffer."
    case .writeFailed(let code):
      "Write operation stopped (error \(code))."
    case .readFailed(let code):
      "Read operation stopped (error \(code))."
    case .integrityMismatch:
      "The data verification found an unexpected mismatch."
    case .cancelled:
      "Test cancelled."
    }
  }
}
