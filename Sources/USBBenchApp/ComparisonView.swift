import Charts
import SwiftUI
import USBBenchCore

struct ComparisonView: View {
  @ObservedObject var model: AppModel
  private var text: AppText { model.text }

  private var availableResults: [SavedBenchmark] {
    model.comparisonResults
  }

  private var resultA: SavedBenchmark? {
    availableResults.first { $0.id == model.comparisonAID }
  }

  private var resultB: SavedBenchmark? {
    availableResults.first { $0.id == model.comparisonBID }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      if availableResults.count < 2 {
        ContentUnavailableView {
          Label(
            text("Servono due risultati", "Two results are required"),
            systemImage: "chart.bar.xaxis"
          )
        } description: {
          Text(
            text(
              "Salva almeno due test compatibili con il filtro selezionato.",
              "Save at least two tests matching the selected filter."
            )
          )
        } actions: {
          Button(text("Nuovo test", "New test")) { model.section = .newTest }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let resultA, let resultB {
        ScrollView {
          VStack(spacing: 16) {
            selectors
            validityCard(resultA, resultB)
            chartCard(resultA, resultB)
            deltaCard(resultA, resultB)
          }
          .padding(.bottom, 20)
        }
      }
    }
    .padding(26)
    .onAppear {
      model.normalizeComparisonSelection()
    }
    .onChange(of: model.comparisonFilter) { _, _ in
      model.normalizeComparisonSelection()
    }
  }

  private var header: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 18) {
        comparisonTitle
        Spacer()
        filterControl
      }
      VStack(alignment: .leading, spacing: 12) {
        comparisonTitle
        filterControl
      }
    }
  }

  private var comparisonTitle: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(text("Confronto", "Comparison"))
        .font(.largeTitle.bold())
      Text(
        text(
          "Le differenze sono attendibili solo quando il resto della catena rimane uguale.",
          "Differences are meaningful only when the rest of the chain stays unchanged."
        )
      )
      .foregroundStyle(.secondary)
    }
  }

  private var filterControl: some View {
    Picker(text("Filtro", "Filter"), selection: $model.comparisonFilter) {
      ForEach(ResultKindFilter.allCases) { filter in
        Text(filter.title(text)).tag(filter)
      }
    }
    .frame(width: 175)
    .help(
      text(
        "Limita entrambi i selettori a cavi o dispositivi.",
        "Limit both selectors to cables or devices."
      )
    )
  }

  private var selectors: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 14) {
        resultPicker(text("Risultato A", "Result A"), selection: $model.comparisonAID)
        Image(systemName: "arrow.left.arrow.right")
          .foregroundStyle(.secondary)
        resultPicker(text("Risultato B", "Result B"), selection: $model.comparisonBID)
      }
      VStack(spacing: 10) {
        resultPicker(text("Risultato A", "Result A"), selection: $model.comparisonAID)
        resultPicker(text("Risultato B", "Result B"), selection: $model.comparisonBID)
      }
    }
    .appCard()
  }

  private func resultPicker(_ title: String, selection: Binding<UUID?>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Picker(title, selection: selection) {
        ForEach(availableResults) { result in
          Text(
            "\(result.subjectName) · \(Formatters.date(result.createdAt, language: model.language))"
          )
          .tag(Optional(result.id))
        }
      }
      .labelsHidden()
    }
    .frame(maxWidth: .infinity)
  }

  private func validityCard(_ a: SavedBenchmark, _ b: SavedBenchmark) -> some View {
    let warnings = comparisonWarnings(a, b)
    return HStack(alignment: .top, spacing: 13) {
      Image(systemName: warnings.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
        .font(.title2)
        .foregroundStyle(warnings.isEmpty ? AppTheme.green : AppTheme.orange)
      VStack(alignment: .leading, spacing: 5) {
        Text(
          warnings.isEmpty
            ? text("Confronto coerente", "Comparable setup")
            : text("Setup non perfettamente allineato", "Setup mismatch")
        )
        .font(.headline)
        if warnings.isEmpty {
          Text(
            text(
              "Volume, protocollo di misura, profilo e dimensione coincidono.",
              "Drive, measurement protocol, profile and file size match."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        } else {
          ForEach(warnings, id: \.self) { warning in
            Text("• \(warning)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      Spacer()
    }
    .appCard()
  }

  private func chartCard(_ a: SavedBenchmark, _ b: SavedBenchmark) -> some View {
    let bars = comparisonBars(a, b)
    return VStack(alignment: .leading, spacing: 14) {
      SectionTitle(
        text("Velocità sequenziale", "Sequential speed"),
        subtitle: text("Più alto è meglio.", "Higher is better.")
      )
      Chart(bars) { bar in
        BarMark(
          x: .value(text("Misura", "Metric"), bar.metric),
          y: .value("MB/s", bar.value)
        )
        .foregroundStyle(by: .value(text("Risultato", "Result"), bar.series))
        .position(by: .value(text("Risultato", "Result"), bar.series))
        .cornerRadius(5)
      }
      .chartForegroundStyleScale([
        "A · \(a.subjectName)": AppTheme.accent,
        "B · \(b.subjectName)": Color(nsColor: .systemIndigo),
      ])
      .chartYAxisLabel("MB/s")
      .frame(height: 260)
    }
    .appCard()
  }

  private func deltaCard(_ a: SavedBenchmark, _ b: SavedBenchmark) -> some View {
    let writeDelta = percentDelta(
      from: a.measurement.sequentialWriteMBps,
      to: b.measurement.sequentialWriteMBps
    )
    let readDelta = percentDelta(
      from: a.measurement.sequentialReadMBps,
      to: b.measurement.sequentialReadMBps
    )
    let meaningful = [writeDelta, readDelta]
      .compactMap { $0 }
      .max(by: { abs($0) < abs($1) })

    return VStack(alignment: .leading, spacing: 14) {
      SectionTitle(text("Differenza di B rispetto ad A", "Difference: B versus A"))
      HStack(spacing: 12) {
        deltaTile(text("Scrittura", "Write"), value: writeDelta)
        deltaTile(text("Lettura", "Read"), value: readDelta)
      }

      if let meaningful {
        Divider()
        Label(
          abs(meaningful) < 5
            ? text(
              "Nessuna differenza significativa: lo scarto principale è sotto il 5%.",
              "No meaningful difference: the largest gap is below 5%."
            )
            : meaningful > 0
              ? text(
                "B è più veloce nella misura con lo scarto maggiore.",
                "B is faster in the metric with the largest gap."
              )
              : text(
                "B è più lento nella misura con lo scarto maggiore.",
                "B is slower in the metric with the largest gap."
              ),
          systemImage: abs(meaningful) < 5
            ? "equal.circle.fill"
            : meaningful > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(
          abs(meaningful) < 5
            ? .secondary
            : meaningful > 0 ? AppTheme.green : AppTheme.orange
        )
      }
    }
    .appCard()
  }

  private func deltaTile(_ title: String, value: Double?) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value.map { String(format: "%+.1f%%", $0) } ?? "—")
        .font(.system(size: 27, weight: .semibold, design: .rounded))
        .foregroundStyle(
          value.map { abs($0) < 5 ? Color.secondary : ($0 > 0 ? AppTheme.green : AppTheme.orange) }
            ?? .secondary
        )
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 13))
  }

  private func comparisonWarnings(_ a: SavedBenchmark, _ b: SavedBenchmark) -> [String] {
    var warnings: [String] = []
    if a.volume.stableIdentifier != b.volume.stableIdentifier {
      warnings.append(
        text(
          "Il volume fisico o il suo identificatore è diverso.",
          "The physical drive or its identifier is different."
        )
      )
    }
    if a.profile != b.profile || a.selection != b.selection {
      warnings.append(
        text(
          "Il profilo o il tipo di test è diverso.",
          "The profile or test type is different."
        )
      )
    }
    if a.fileSizeBytes != b.fileSizeBytes {
      warnings.append(
        text(
          "La dimensione del file di prova è diversa.",
          "The test-file size is different."
        )
      )
    }
    if a.subjectKind == .cable,
      b.subjectKind == .cable,
      a.referenceResultID != b.referenceResultID
    {
      warnings.append(
        text(
          "I cavi non usano lo stesso dispositivo di riferimento.",
          "The cables do not use the same reference drive."
        )
      )
    }
    if a.host.model != b.host.model {
      warnings.append(
        text(
          "I test sono stati eseguiti su Mac diversi.",
          "The tests were run on different Macs."
        )
      )
    }
    if (a.measurement.measurementProtocolVersion ?? 1)
      != (b.measurement.measurementProtocolVersion ?? 1)
    {
      warnings.append(
        text(
          "Il protocollo del motore di misura è diverso.",
          "The measurement-engine protocol is different."
        )
      )
    }
    if a.volume.negotiatedSpeed != b.volume.negotiatedSpeed {
      warnings.append(
        text(
          "La velocità USB negoziata è diversa o non è disponibile in uno dei test.",
          "The negotiated USB speed differs or is unavailable in one test."
        )
      )
    }
    return warnings
  }

  private func percentDelta(from: Double?, to: Double?) -> Double? {
    guard let from, let to, from > 0 else { return nil }
    return (to - from) / from * 100
  }

  private func comparisonBars(_ a: SavedBenchmark, _ b: SavedBenchmark) -> [ComparisonBar] {
    var bars: [ComparisonBar] = []
    if let value = a.measurement.sequentialWriteMBps {
      bars.append(
        .init(
          metric: text("Scrittura", "Write"),
          series: "A · \(a.subjectName)",
          value: value
        )
      )
    }
    if let value = b.measurement.sequentialWriteMBps {
      bars.append(
        .init(
          metric: text("Scrittura", "Write"),
          series: "B · \(b.subjectName)",
          value: value
        )
      )
    }
    if let value = a.measurement.sequentialReadMBps {
      bars.append(
        .init(
          metric: text("Lettura", "Read"),
          series: "A · \(a.subjectName)",
          value: value
        )
      )
    }
    if let value = b.measurement.sequentialReadMBps {
      bars.append(
        .init(
          metric: text("Lettura", "Read"),
          series: "B · \(b.subjectName)",
          value: value
        )
      )
    }
    return bars
  }
}

private struct ComparisonBar: Identifiable {
  let id = UUID()
  let metric: String
  let series: String
  let value: Double
}
