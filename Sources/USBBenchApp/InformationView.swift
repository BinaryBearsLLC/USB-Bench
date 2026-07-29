import SwiftUI

struct InformationView: View {
  @ObservedObject var model: AppModel

  private var text: AppText { model.text }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text(text("Informazioni", "Information"))
            .font(.largeTitle.bold())
          Text(
            text(
              "Come ottenere misure confrontabili.",
              "How to obtain comparable measurements."
            )
          )
          .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text("Cosa misura", "What it measures"))
          Text(
            text(
              "Il risultato comprende l’intera catena: unità, enclosure, cavo, hub, porta, filesystem e temperatura. Per isolare un cavo mantieni invariati tutti gli altri elementi. Per isolare un dispositivo usa sempre lo stesso cavo e la stessa porta.",
              "A result covers the whole chain: drive, enclosure, cable, hub, port, file system and temperature. To isolate a cable, keep every other component unchanged. To isolate a drive, always use the same cable and port."
            )
          )
          .foregroundStyle(.secondary)
          Label(
            text(
              "Un cavo può essere verificato soltanto fino alla velocità negoziata dal collegamento.",
              "A cable can only be verified up to the speed negotiated by the connection."
            ),
            systemImage: "link"
          )
          .font(.subheadline)
        }
        .appCard()

        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text("Sicurezza", "Safety"))
          infoRow(
            text("File temporaneo", "Temporary file"),
            text(
              "Viene creato nella posizione scelta con un nome univoco e rimosso al termine.",
              "It is created in the selected location with a unique name and removed when finished."
            )
          )
          infoRow(
            text("File esistenti", "Existing files"),
            text(
              "Non vengono aperti, letti, modificati o cancellati.",
              "They are not opened, read, changed or deleted."
            )
          )
          infoRow(
            text("Nessun disco grezzo", "No raw-disk access"),
            text(
              "L’app non formatta, non smonta e non scrive su /dev/disk.",
              "The app does not format, unmount or write to /dev/disk."
            )
          )
          infoRow(
            text("Cache di macOS", "macOS cache"),
            text(
              "F_NOCACHE è obbligatorio: se macOS lo rifiuta, il test si interrompe.",
              "F_NOCACHE is mandatory. If macOS rejects it, the test stops."
            )
          )
          infoRow(
            text("Verifica", "Verification"),
            text(
              "I dati vengono controllati fuori dal tempo misurato.",
              "Data is checked outside the timed measurement."
            )
          )
        }
        .appCard()

        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text("Risultati", "Results"))
          Text(
            text(
              "La scrittura principale misura il trasferimento. La scrittura persistita include anche la sincronizzazione su unità. I risultati vengono salvati solo quando lo richiedi e possono essere ripristinati dal Cestino.",
              "The main write value measures transfer speed. Durable write also includes the drive synchronization. Results are saved only when requested and can be restored from Trash."
            )
          )
          .foregroundStyle(.secondary)
        }
        .appCard()

        VStack(alignment: .leading, spacing: 12) {
          SectionTitle(text("BinaryBears", "BinaryBears"))
          Text(
            text(
              "USB Bench è sviluppata da BinaryBears, società BinaryBears LLC, ed è distribuita come software open source con licenza MIT.",
              "USB Bench is developed by BinaryBears, a BinaryBears LLC product, and released as open-source software under the MIT License."
            )
          )
          .foregroundStyle(.secondary)
          Link("binarybears.com", destination: URL(string: "https://binarybears.com")!)
            .help(
              text(
                "Apre il sito BinaryBears nel browser.",
                "Opens the BinaryBears website in your browser."
              )
            )
          Link(
            "github.com/BinaryBearsLLC/USB-Bench",
            destination: URL(string: "https://github.com/BinaryBearsLLC/USB-Bench")!
          )
          .help(
            text(
              "Apre il repository pubblico di USB Bench.",
              "Opens the public USB Bench repository."
            )
          )
        }
        .appCard()
      }
      .padding(24)
      .frame(maxWidth: 820, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func infoRow(_ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "checkmark.circle")
        .foregroundStyle(.secondary)
        .padding(.top, 1)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.medium))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
