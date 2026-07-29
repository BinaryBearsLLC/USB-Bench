import SwiftUI
import USBBenchCore

enum AppTheme {
  static let accent = Color.accentColor
  static let green = Color(nsColor: .systemGreen)
  static let orange = Color(nsColor: .systemOrange)
  static let red = Color(nsColor: .systemRed)
}

struct CardModifier: ViewModifier {
  var padding: CGFloat = 16

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
      }
  }
}

extension View {
  func appCard(padding: CGFloat = 18) -> some View {
    modifier(CardModifier(padding: padding))
  }
}

struct SectionTitle: View {
  let title: String
  let subtitle: String?

  init(_ title: String, subtitle: String? = nil) {
    self.title = title
    self.subtitle = subtitle
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.headline)
      if let subtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct InlineHelp: View {
  let message: String

  var body: some View {
    Image(systemName: "info.circle")
      .foregroundStyle(.tertiary)
      .help(message)
      .accessibilityLabel(message)
  }
}

struct MetricTile: View {
  let title: String
  let value: Double?
  let unit: String
  var color: Color = AppTheme.accent
  var decimals = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(formattedValue)
          .font(.system(size: 28, weight: .semibold, design: .rounded))
          .contentTransition(.numericText())
        Text(unit)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(nsColor: .textBackgroundColor).opacity(0.55),
      in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.quaternary, lineWidth: 0.5)
    }
  }

  private var formattedValue: String {
    guard let value else { return "—" }
    return String(format: "%.\(decimals)f", value)
  }
}

struct ResultMetricsGrid: View {
  let result: SavedBenchmark
  let text: AppText

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 10),
          GridItem(.flexible(), spacing: 10),
        ],
        spacing: 10
      ) {
        MetricTile(
          title: text("Scrittura sequenziale", "Sequential write"),
          value: result.measurement.sequentialWriteMBps,
          unit: "MB/s",
          color: AppTheme.accent
        )
        MetricTile(
          title: text("Lettura sequenziale", "Sequential read"),
          value: result.measurement.sequentialReadMBps,
          unit: "MB/s",
          color: AppTheme.accent
        )
        if result.measurement.randomReadIOPS != nil {
          MetricTile(
            title: text("Lettura casuale 4K", "4K random read"),
            value: result.measurement.randomReadIOPS,
            unit: "IOPS",
            color: AppTheme.green
          )
        }
        if result.measurement.randomWriteIOPS != nil {
          MetricTile(
            title: text("Scrittura casuale 4K", "4K random write"),
            value: result.measurement.randomWriteIOPS,
            unit: "IOPS",
            color: AppTheme.orange
          )
        }
      }
      if let durable = result.measurement.sequentialWriteDurableMBps
        ?? result.measurement.sequentialWriteMBps,
        let flush = result.measurement.averageFlushSeconds
      {
        Text(
          text(
            "Scrittura persistita \(Formatters.speed(durable)); sincronizzazione \(result.measurement.flushPolicy ?? "") media \(String(format: "%.3f s", flush)).",
            "Durable write \(Formatters.speed(durable)); average \(result.measurement.flushPolicy ?? "") sync \(String(format: "%.3f s", flush))."
          )
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
    }
  }
}

enum Formatters {
  static func date(_ value: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.locale = language.locale
    return formatter.string(from: value)
  }

  static func bytes(_ count: Int64?) -> String {
    guard let count else { return "—" }
    return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
  }

  static func duration(_ seconds: Double) -> String {
    if seconds < 60 {
      return String(format: "%.1f s", seconds)
    }
    return String(format: "%.1f min", seconds / 60)
  }

  static func speed(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f MB/s", value)
  }
}
