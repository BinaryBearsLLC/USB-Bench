import SwiftUI

@main
struct USBBenchApplication: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
    }
    .defaultSize(width: 1_120, height: 760)
    .windowStyle(.automatic)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button(model.text("Nuovo test", "New test")) {
          model.section = .newTest
        }
        .keyboardShortcut("n", modifiers: .command)
      }
      CommandGroup(replacing: .appSettings) {
        Button(model.text("Impostazioni…", "Settings…")) {
          model.section = .settings
        }
        .keyboardShortcut(",", modifiers: .command)
      }
      CommandGroup(after: .importExport) {
        Button(model.text("Esporta risultati…", "Export results…")) {
          model.exportCSV(model.savedResults)
        }
        .disabled(model.savedResults.isEmpty)
      }
    }
  }
}
