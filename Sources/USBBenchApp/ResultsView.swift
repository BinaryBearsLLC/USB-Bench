import SwiftUI
import USBBenchCore

private enum ResultsScope: String, CaseIterable, Identifiable {
  case active
  case trash

  var id: String { rawValue }
}

struct ResultsView: View {
  @ObservedObject var model: AppModel
  @State private var search = ""
  @State private var kindFilter: ResultKindFilter = .all
  @State private var scope: ResultsScope = .active
  @State private var selectedResult: SavedBenchmark?
  @State private var deleteCandidate: SavedBenchmark?

  private var text: AppText { model.text }

  private var sourceResults: [SavedBenchmark] {
    scope == .active ? model.savedResults : model.trashedResults
  }

  private var filteredResults: [SavedBenchmark] {
    let matchingKind = sourceResults.filter {
      kindFilter.matches($0.subjectKind)
    }
    guard !search.isEmpty else { return matchingKind }
    return matchingKind.filter {
      $0.subjectName.localizedCaseInsensitiveContains(search)
        || $0.notes.localizedCaseInsensitiveContains(search)
        || $0.volume.name.localizedCaseInsensitiveContains(search)
        || ($0.volume.mediaName?.localizedCaseInsensitiveContains(search) ?? false)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      Picker(text("Vista", "View"), selection: $scope) {
        Text(
          text("Risultati (\(model.savedResults.count))", "Results (\(model.savedResults.count))")
        )
        .tag(ResultsScope.active)
        Text(
          text("Cestino (\(model.trashedResults.count))", "Trash (\(model.trashedResults.count))")
        )
        .tag(ResultsScope.trash)
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 360)

      if filteredResults.isEmpty {
        emptyState
      } else {
        resultsTable
      }
    }
    .padding(24)
    .sheet(item: $selectedResult) { result in
      ResultDetailView(result: result, text: text)
    }
    .confirmationDialog(
      text(
        "Eliminare definitivamente questo risultato?",
        "Permanently delete this result?"
      ),
      isPresented: Binding(
        get: { deleteCandidate != nil },
        set: { if !$0 { deleteCandidate = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(text("Elimina definitivamente", "Delete permanently"), role: .destructive) {
        if let deleteCandidate {
          model.deleteResultPermanently(deleteCandidate)
        }
        deleteCandidate = nil
      }
      Button(text("Annulla", "Cancel"), role: .cancel) {
        deleteCandidate = nil
      }
    } message: {
      Text(
        text(
          "Questa operazione non può essere annullata.",
          "This action cannot be undone."
        )
      )
    }
  }

  private var header: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 12) {
        title
        Spacer()
        controls
      }
      VStack(alignment: .leading, spacing: 10) {
        title
        controls
      }
    }
  }

  private var title: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(text("Risultati", "Results"))
        .font(.largeTitle.bold())
      Text(
        text(
          "Salvati solo nel database locale.",
          "Stored only in the local database."
        )
      )
      .foregroundStyle(.secondary)
    }
  }

  private var controls: some View {
    HStack {
      Picker(text("Filtro", "Filter"), selection: $kindFilter) {
        ForEach(ResultKindFilter.allCases) { filter in
          Text(filter.title(text)).tag(filter)
        }
      }
      .frame(width: 155)
      .help(
        text(
          "Mostra tutti i risultati oppure soltanto cavi o dispositivi.",
          "Show all results, cables only, or devices only."
        )
      )
      TextField(text("Cerca", "Search"), text: $search)
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: 160, idealWidth: 220, maxWidth: 240)
      Button(text("Esporta CSV", "Export CSV"), systemImage: "square.and.arrow.up") {
        model.exportCSV(filteredResults)
      }
      .disabled(filteredResults.isEmpty || scope == .trash)
      .help(
        text(
          "Esporta i risultati visibili in un file CSV.",
          "Export the visible results to a CSV file."
        )
      )
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label(
        emptyTitle,
        systemImage: scope == .trash ? "trash" : "tray"
      )
    } description: {
      Text(emptyDescription)
    } actions: {
      if scope == .active, search.isEmpty {
        Button(text("Nuovo test", "New test")) {
          model.section = .newTest
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyTitle: String {
    if !search.isEmpty || kindFilter != .all {
      return text("Nessun risultato", "No results")
    }
    return scope == .trash
      ? text("Il Cestino è vuoto", "Trash is empty")
      : text("Nessun risultato salvato", "No saved results")
  }

  private var emptyDescription: String {
    if !search.isEmpty || kindFilter != .all {
      return text(
        "Prova a cambiare ricerca o filtro.",
        "Try changing the search or filter."
      )
    }
    return scope == .trash
      ? text(
        "I risultati cestinati possono essere ripristinati da qui.",
        "Trashed results can be restored here."
      )
      : text(
        "Al termine di un test scegli “Salva risultato”.",
        "Choose “Save result” when a test finishes."
      )
  }

  private var resultsTable: some View {
    Table(filteredResults) {
      TableColumn(text("Nome", "Name")) { result in
        Button {
          selectedResult = result
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(result.subjectName)
              .font(.headline)
            Text("\(text.subject(result.subjectKind)) · \(result.volume.name)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
      }
      .width(min: 180, ideal: 260)

      TableColumn(text("Profilo", "Profile")) { result in
        Text(text.profile(result.profile))
      }
      .width(min: 70, ideal: 90)

      TableColumn(text("Scrittura", "Write")) { result in
        Text(Formatters.speed(result.measurement.sequentialWriteMBps))
          .monospacedDigit()
      }
      .width(min: 85, ideal: 100)

      TableColumn(text("Lettura", "Read")) { result in
        Text(Formatters.speed(result.measurement.sequentialReadMBps))
          .monospacedDigit()
      }
      .width(min: 85, ideal: 100)

      TableColumn(text("Data", "Date")) { result in
        Text(Formatters.date(result.createdAt, language: model.language))
          .foregroundStyle(.secondary)
      }
      .width(min: 120, ideal: 160)

      TableColumn("") { result in
        rowActions(result)
      }
      .width(min: 92, ideal: 112, max: 124)
    }
  }

  private func rowActions(_ result: SavedBenchmark) -> some View {
    HStack(spacing: 5) {
      if scope == .active {
        Button {
          model.prepareComparison(with: result)
        } label: {
          Image(systemName: "chart.bar.xaxis")
        }
        .buttonStyle(.borderless)
        .help(text("Confronta questo risultato", "Compare this result"))

        Button {
          model.trashResult(result)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help(
          text(
            "Sposta nel Cestino; potrai ripristinarlo.",
            "Move to Trash; you can restore it later."
          )
        )
      } else {
        Button {
          model.restoreResult(result)
        } label: {
          Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.borderless)
        .help(text("Ripristina il risultato", "Restore result"))

        Button(role: .destructive) {
          deleteCandidate = result
        } label: {
          Image(systemName: "trash.slash")
        }
        .buttonStyle(.borderless)
        .help(text("Elimina definitivamente", "Delete permanently"))
      }

      Button {
        selectedResult = result
      } label: {
        Image(systemName: "info.circle")
      }
      .buttonStyle(.borderless)
      .help(text("Mostra dettagli", "Show details"))
    }
  }
}

private struct ResultDetailView: View {
  let result: SavedBenchmark
  let text: AppText
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(result.subjectName)
              .font(.largeTitle.bold())
            Text(
              "\(text.subject(result.subjectKind)) · \(Formatters.date(result.createdAt, language: text.language))"
            )
            .foregroundStyle(.secondary)
          }
          Spacer()
          Button(text("Chiudi", "Close"), action: dismiss.callAsFunction)
        }

        ResultMetricsGrid(result: result, text: text)

        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text("Setup", "Setup"))
          LabeledContent(text("Volume", "Drive"), value: result.volume.name)
          if let mediaName = result.volume.mediaName, !mediaName.isEmpty {
            LabeledContent(
              text(
                "Nome comunicato dal dispositivo",
                "Device-reported name"
              ),
              value: mediaName
            )
          }
          LabeledContent(text("Percorso", "Path"), value: result.volume.path)
          LabeledContent(
            text("Protocollo", "Protocol"),
            value: result.volume.busProtocol ?? text("Non rilevato", "Not detected")
          )
          if let speed = result.volume.negotiatedSpeed {
            LabeledContent(
              text("Velocità negoziata", "Negotiated speed"),
              value: speed
            )
          }
          if let connection = text.connection(result.volume.connectionKind) {
            LabeledContent(text("Collegamento", "Connection"), value: connection)
          }
          LabeledContent(
            text("Filesystem", "File system"),
            value: result.volume.fileSystem ?? text("Non rilevato", "Not detected")
          )
          if let deviceIdentifier = result.volume.deviceIdentifier {
            LabeledContent(
              text("Identificatore macOS", "macOS identifier"),
              value: deviceIdentifier
            )
          }
          if let parentWholeDisk = result.volume.parentWholeDisk {
            LabeledContent(
              text("Disco fisico", "Physical disk"),
              value: parentWholeDisk
            )
          }
          if let capacity = result.volume.capacityBytes {
            LabeledContent(
              text("Capacità", "Capacity"),
              value: Formatters.bytes(capacity)
            )
          }
          if let available = result.volume.availableBytes {
            LabeledContent(
              text("Spazio libero al test", "Free space at test time"),
              value: Formatters.bytes(available)
            )
          }
          if let isSolidState = result.volume.isSolidState {
            LabeledContent(
              text("Tipo supporto", "Media type"),
              value: isSolidState
                ? text("Unità a stato solido", "Solid-state drive")
                : text("Unità meccanica o non rilevata", "Mechanical or unidentified drive")
            )
          }
          LabeledContent(
            text("Dimensione test", "Test size"),
            value: Formatters.bytes(result.fileSizeBytes)
          )
          LabeledContent(text("Profilo", "Profile"), value: text.profile(result.profile))
          LabeledContent(
            text("Protocollo misura", "Measurement protocol"),
            value: "v\(result.measurement.measurementProtocolVersion ?? 1)"
          )
          LabeledContent("Mac", value: "\(result.host.model) · \(result.host.architecture)")
        }
        .appCard()
        .textSelection(.enabled)

        if !result.notes.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text("Note", "Notes"))
            Text(result.notes)
              .textSelection(.enabled)
          }
          .appCard()
        }
      }
      .padding(24)
    }
    .frame(minWidth: 620, idealWidth: 680, minHeight: 560, idealHeight: 620)
  }
}
