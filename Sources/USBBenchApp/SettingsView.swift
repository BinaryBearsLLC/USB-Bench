import SwiftUI
import USBBenchCore

struct SettingsView: View {
  @ObservedObject var model: AppModel

  private var text: AppText { model.text }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text(text("Impostazioni", "Settings"))
            .font(.largeTitle.bold())
          Text(
            text(
              "Preferenze dell’app su questo Mac.",
              "App preferences on this Mac."
            )
          )
          .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 14) {
          SectionTitle(text("Aspetto e lingua", "Appearance and language"))
          Picker(text("Aspetto", "Appearance"), selection: $model.appearance) {
            ForEach(AppAppearance.allCases) { appearance in
              Text(appearance.title(text)).tag(appearance)
            }
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 440)
          .help(
            text(
              "Automatica segue l’aspetto chiaro o scuro scelto nelle impostazioni del Mac.",
              "Automatic follows the Light or Dark appearance selected in Mac settings."
            )
          )
          Divider()
          Picker(text("Lingua", "Language"), selection: $model.language) {
            ForEach(AppLanguage.allCases) { language in
              Text(language.displayName).tag(language)
            }
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 360)
          Text(
            text(
              "Le modifiche vengono applicate subito e restano memorizzate su questo Mac.",
              "Changes apply immediately and remain saved on this Mac."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .appCard()

        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text("Applicazione", "Application"))
          LabeledContent(
            text("Sviluppata da", "Developed by"),
            value: "BinaryBears"
          )
          LabeledContent(
            text("Società", "Company"),
            value: "BinaryBears LLC"
          )
          LabeledContent(
            text("Licenza", "License"),
            value: "MIT"
          )
          Link("binarybears.com", destination: URL(string: "https://binarybears.com")!)
            .help(
              text(
                "Apre il sito BinaryBears nel browser.",
                "Opens the BinaryBears website in your browser."
              )
            )
        }
        .appCard()

        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text("Dati", "Data"))
          LabeledContent(
            text("Risultati attivi", "Active results"),
            value: "\(model.savedResults.count)"
          )
          LabeledContent(
            text("Nel Cestino", "In Trash"),
            value: "\(model.trashedResults.count)"
          )
          Text(
            text(
              "Risultati e Cestino sono conservati nel database locale. Nessun dato viene inviato online.",
              "Results and Trash are stored in the local database. No data is sent online."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .appCard()

        VStack(alignment: .leading, spacing: 10) {
          SectionTitle(text("Motore di misura", "Measurement engine"))
          LabeledContent(
            text("Protocollo", "Protocol"),
            value: "v\(BenchmarkEngine.measurementProtocolVersion)"
          )
          LabeledContent("Cache", value: "F_NOCACHE")
          Text(
            text(
              "I risultati creati con protocolli diversi vengono segnalati nel confronto.",
              "Comparisons flag results created with different measurement protocols."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .appCard()
      }
      .frame(maxWidth: 720, alignment: .leading)
      .padding(24)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
