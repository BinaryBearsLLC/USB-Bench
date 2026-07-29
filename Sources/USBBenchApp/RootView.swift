import SwiftUI

struct RootView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationSplitView {
      sidebar
    } detail: {
      detail
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    .navigationSplitViewStyle(.balanced)
    .tint(AppTheme.accent)
    .preferredColorScheme(model.appearance.colorScheme)
    .frame(minWidth: 820, minHeight: 650)
    .alert(item: $model.alert) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private var sidebar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 11) {
        Image(systemName: "cable.connector.horizontal")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
        VStack(alignment: .leading, spacing: 1) {
          Text("USB Bench")
            .font(.headline)
          Text(model.text("Cavi e unità", "Cables and drives"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(16)

      List(SidebarSection.allCases, selection: $model.section) { item in
        Label(item.title(model.text), systemImage: item.symbol)
          .tag(item)
          .padding(.vertical, 4)
      }
      .listStyle(.sidebar)

      Divider()
      Link(destination: URL(string: "https://binarybears.com")!) {
        HStack(spacing: 9) {
          Image(systemName: "pawprint.fill")
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 1) {
            Text("BinaryBears")
              .font(.caption.weight(.semibold))
            Text(model.text("BinaryBears LLC · Open source", "BinaryBears LLC · Open source"))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("binarybears.com")
      .padding(14)
    }
    .navigationSplitViewColumnWidth(min: 205, ideal: 220, max: 250)
  }

  @ViewBuilder
  private var detail: some View {
    switch model.section {
    case .newTest:
      NewTestView(model: model)
    case .results:
      ResultsView(model: model)
    case .comparison:
      ComparisonView(model: model)
    case .information:
      InformationView(model: model)
    case .settings:
      SettingsView(model: model)
    }
  }
}
