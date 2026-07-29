import SwiftUI
import USBBenchCore

struct NewTestView: View {
  @ObservedObject var model: AppModel

  private var text: AppText { model.text }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 18) {
            configurationColumn
              .frame(minWidth: 460, maxWidth: .infinity, alignment: .topLeading)
            runPanel
              .frame(minWidth: 320, idealWidth: 360, maxWidth: 380)
          }
          .frame(minWidth: 820, alignment: .topLeading)

          VStack(alignment: .leading, spacing: 18) {
            configurationColumn
            runPanel
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding(24)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(text("Nuovo test", "New test"))
        .font(.largeTitle.bold())
      Text(
        text(
          "Mantieni invariato il resto del setup e cambia un solo componente.",
          "Keep the rest of the setup unchanged and swap one component at a time."
        )
      )
      .foregroundStyle(.secondary)
    }
  }

  private var configurationColumn: some View {
    VStack(alignment: .leading, spacing: 14) {
      subjectPanel
      targetPanel
      profilePanel
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var subjectPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        SectionTitle(
          text("1. Componente", "1. Component"),
          subtitle: text(
            "Scegli cosa vuoi confrontare.",
            "Choose what you want to compare."
          )
        )
        InlineHelp(
          message: text(
            "Il motore del test non cambia. La scelta serve a costruire confronti coerenti tra dispositivi o tra cavi.",
            "The benchmark engine stays the same. This choice keeps device and cable comparisons consistent."
          )
        )
      }

      Picker(text("Tipo", "Type"), selection: $model.subjectKind) {
        ForEach(SubjectKind.allCases) { kind in
          Text(text.subject(kind)).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      .help(
        text(
          "Per testare un cavo usa sempre lo stesso SSD veloce e la stessa porta.",
          "To test a cable, always use the same fast SSD and the same port."
        )
      )

      TextField(
        model.subjectKind == .cable
          ? text("Nome del cavo", "Cable name")
          : text("Nome del dispositivo", "Device name"),
        text: $model.subjectName
      )
      .textFieldStyle(.roundedBorder)

      TextField(
        text("Note sul setup (facoltative)", "Setup notes (optional)"),
        text: $model.notes,
        axis: .vertical
      )
      .lineLimit(2...4)
      .textFieldStyle(.roundedBorder)

      if model.subjectKind == .cable {
        Divider()
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text(text("Riferimento", "Reference"))
            .font(.subheadline.weight(.medium))
          InlineHelp(
            message: text(
              "Il riferimento non modifica il test: documenta quale unità hai mantenuto invariata.",
              "The reference does not change the test. It records which drive stayed unchanged."
            )
          )
        }
        Picker(
          text("Dispositivo di riferimento", "Reference device"),
          selection: $model.referenceResultID
        ) {
          Text(text("Nessun riferimento", "No reference")).tag("")
          ForEach(model.deviceReferences) { result in
            Text(
              "\(result.subjectName) · \(Formatters.speed(result.measurement.sequentialReadMBps))"
            )
            .tag(result.id.uuidString)
          }
        }

        if model.deviceReferences.isEmpty {
          Label(
            text(
              "Salva prima un test del dispositivo usato come riferimento.",
              "Save a test of the reference drive first."
            ),
            systemImage: "lightbulb"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Picker(
          text("Velocità dichiarata del cavo", "Cable rated speed"),
          selection: $model.claimedCableSpeed
        ) {
          ForEach(CableSpeedClaim.allCases) { claim in
            Text(claim.title(text)).tag(claim)
          }
        }
        .help(
          text(
            "È la banda nominale del cavo, non la velocità garantita del disco.",
            "This is the cable's nominal bandwidth, not a guaranteed drive speed."
          )
        )
      }
    }
    .appCard()
  }

  private var targetPanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        SectionTitle(
          text("2. Unità di test", "2. Test drive"),
          subtitle: text(
            "Scegli il volume o una cartella al suo interno.",
            "Choose the volume or a folder on it."
          )
        )
        Spacer()
        Button(text("Scegli…", "Choose…"), systemImage: "externaldrive.badge.plus") {
          model.chooseTarget()
        }
        .buttonStyle(.bordered)
        .help(
          text(
            "L’app crea solo un file temporaneo con nome univoco e lo rimuove al termine.",
            "The app creates one uniquely named temporary file and removes it when finished."
          )
        )
      }

      if model.isInspectingVolume {
        HStack {
          ProgressView()
            .controlSize(.small)
          Text(text("Leggo le informazioni dell’unità…", "Reading drive information…"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else if let volume = model.selectedVolume {
        HStack(alignment: .top, spacing: 12) {
          Image(
            systemName: volume.isSolidState == true
              ? "externaldrive.fill.badge.checkmark"
              : "externaldrive.fill"
          )
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
          .frame(width: 32)

          VStack(alignment: .leading, spacing: 4) {
            Text(volume.name)
              .font(.headline)
            Text(volume.mediaName ?? volume.path)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          Spacer()
          Label(
            volume.isRemovable
              ? text("Esterno", "External")
              : text("Locale", "Local"),
            systemImage: volume.isRemovable ? "cable.connector" : "internaldrive"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Divider()

        ViewThatFits(in: .horizontal) {
          HStack(spacing: 18) {
            volumeFact(
              text("Protocollo", "Protocol"),
              volume.busProtocol ?? text("Non rilevato", "Not detected")
            )
            volumeFact(
              text("Filesystem", "File system"),
              volume.fileSystem ?? text("Non rilevato", "Not detected")
            )
            if let connection = text.connection(volume.connectionKind) {
              volumeFact(text("Percorso", "Route"), connection)
            }
          }
          VStack(alignment: .leading, spacing: 8) {
            volumeFact(
              text("Protocollo", "Protocol"),
              volume.busProtocol ?? text("Non rilevato", "Not detected")
            )
            volumeFact(
              text("Filesystem", "File system"),
              volume.fileSystem ?? text("Non rilevato", "Not detected")
            )
            if let connection = text.connection(volume.connectionKind) {
              volumeFact(text("Percorso", "Route"), connection)
            }
          }
        }

        Divider()
        negotiationPreflight(volume)

        if let preflight = model.spacePreflight {
          Divider()
          HStack(alignment: .firstTextBaseline) {
            Label(
              text(
                "\(Formatters.bytes(preflight.available)) liberi",
                "\(Formatters.bytes(preflight.available)) free"
              ),
              systemImage: "externaldrive"
            )
            Spacer()
            Label(
              text(
                "\(Formatters.bytes(preflight.required)) richiesti",
                "\(Formatters.bytes(preflight.required)) required"
              ),
              systemImage: preflight.isEnough
                ? "checkmark.circle"
                : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(preflight.isEnough ? .secondary : AppTheme.red)
          }
          .font(.caption)
        }

        if let warning = model.cableVerificationWarning {
          Label(warning, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(AppTheme.orange)
        }

        if volume.path == "/" {
          Label(
            text(
              "È il disco di sistema: scegli invece l’unità esterna in /Volumes.",
              "This is the system drive. Choose the external drive under /Volumes."
            ),
            systemImage: "exclamationmark.triangle.fill"
          )
          .font(.caption)
          .foregroundStyle(AppTheme.orange)
        }
      } else {
        Label(
          text("Nessuna unità selezionata", "No drive selected"),
          systemImage: "externaldrive.badge.questionmark"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
    .appCard()
  }

  private func volumeFact(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.weight(.medium))
    }
  }

  private func negotiationPreflight(_ volume: VolumeMetadata) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(
        systemName: volume.negotiatedSpeed == nil
          ? "exclamationmark.triangle.fill"
          : "checkmark.circle.fill"
      )
      .foregroundStyle(volume.negotiatedSpeed == nil ? AppTheme.orange : AppTheme.green)
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 3) {
        Text(
          text(
            "Controllo preliminare del collegamento",
            "Connection preflight"
          )
        )
        .font(.subheadline.weight(.semibold))

        if let speed = volume.negotiatedSpeed {
          Text(
            text(
              "Mac e unità hanno negoziato \(speed).",
              "The Mac and drive negotiated \(speed)."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)

          if let ceiling = model.practicalLinkCeilingMBps {
            Text(
              text(
                "Limite pratico stimato: circa \(Formatters.speed(ceiling)).",
                "Estimated practical ceiling: about \(Formatters.speed(ceiling))."
              )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        } else {
          Text(
            text(
              "macOS non ha fornito la velocità negoziata; il benchmark può proseguire, ma il limite del collegamento non sarà certificabile.",
              "macOS did not provide the negotiated speed. The benchmark can continue, but the connection limit cannot be certified."
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Text(volume.negotiatedSpeed ?? text("Non rilevata", "Not detected"))
        .font(.headline.monospacedDigit())
    }
    .help(
      text(
        "È la velocità concordata automaticamente da Mac, porta, cavo, hub e unità; non è ancora il risultato del benchmark.",
        "This is the speed automatically agreed by the Mac, port, cable, hub and drive; it is not the benchmark result."
      )
    )
  }

  private var profilePanel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        SectionTitle(
          text("3. Tipo di test", "3. Test type"),
          subtitle: text(
            "Rapido: sequenziale. Completo: aggiunge 4K e più stabilità.",
            "Quick: sequential. Complete: adds 4K tests and more stability."
          )
        )
        InlineHelp(
          message: text(
            "Il test completo richiede più tempo e scrive più dati. Il test singolo misura una sola operazione.",
            "The complete test takes longer and writes more data. Single measures one operation."
          )
        )
      }

      Picker(
        text("Profilo", "Profile"),
        selection: Binding(
          get: { model.profile },
          set: { model.setProfile($0) }
        )
      ) {
        ForEach(BenchmarkProfile.allCases) { profile in
          Text(text.profile(profile)).tag(profile)
        }
      }
      .pickerStyle(.segmented)

      if model.profile == .single {
        Picker(text("Misura", "Operation"), selection: $model.singleSelection) {
          ForEach(
            BenchmarkSelection.allCases.filter {
              $0 != .all && $0 != .sequential
            }
          ) { selection in
            Text(text.selection(selection)).tag(selection)
          }
        }
      }

      Picker(text("Dimensione file", "File size"), selection: $model.selectedSizeBytes) {
        ForEach(BenchmarkSizeOption.options) { option in
          Text("\(option.label) · \(option.localizedDetail(text))").tag(option.bytes)
        }
      }
      .help(
        text(
          "Un file più grande riduce l’effetto delle cache del dispositivo, ma richiede più tempo.",
          "A larger file reduces device-cache effects but takes longer."
        )
      )

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) { profileFacts }
        VStack(alignment: .leading, spacing: 7) { profileFacts }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .appCard()
  }

  @ViewBuilder
  private var profileFacts: some View {
    Label(
      text(
        "\(model.configuredPasses) passaggi misurati",
        "\(model.configuredPasses) measured passes"
      ),
      systemImage: "repeat"
    )
    Label(
      text(
        "almeno \(Formatters.bytes(model.estimatedWriteBytes)) scritti",
        "at least \(Formatters.bytes(model.estimatedWriteBytes)) written"
      ),
      systemImage: "square.and.arrow.down"
    )
    if model.profile == .complete {
      Label("4K QD1", systemImage: "square.grid.3x3")
    }
  }

  private var runPanel: some View {
    VStack(alignment: .leading, spacing: 16) {
      if model.isRunning {
        runningContent
      } else if let result = model.currentResult {
        completedContent(result)
      } else {
        readyContent
      }
    }
    .appCard()
  }

  private var readyContent: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionTitle(
        text("Riepilogo", "Summary"),
        subtitle: text(
          "Controlla il setup prima di avviare.",
          "Check the setup before starting."
        )
      )

      if let volume = model.selectedVolume {
        LabeledContent(text("Unità", "Drive"), value: volume.name)
        if let speed = volume.negotiatedSpeed {
          LabeledContent(
            text("Velocità negoziata", "Negotiated speed"),
            value: speed
          )
        }
      } else {
        Text(text("Seleziona l’unità da misurare.", "Select the drive to measure."))
          .foregroundStyle(.secondary)
      }
      LabeledContent(text("Profilo", "Profile"), value: text.profile(model.profile))
      LabeledContent(
        text("Spazio temporaneo", "Temporary space"),
        value: Formatters.bytes(model.requiredFreeSpace)
      )

      Divider()

      Label(
        text(
          "L’app non legge i file esistenti. Crea e rimuove solo il proprio file temporaneo.",
          "The app does not read existing files. It creates and removes only its own temporary file."
        ),
        systemImage: "lock.shield"
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      Button {
        model.startTest()
      } label: {
        Label(text("Avvia test", "Start test"), systemImage: "play.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.canStart)
      .help(
        model.startDisabledReason
          ?? text(
            "Avvia il benchmark con le impostazioni selezionate.",
            "Start the benchmark with the selected settings."
          )
      )

      if let reason = model.startDisabledReason {
        Text(reason)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
  }

  private var runningContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text(text.stage(model.progress.stage))
            .font(.title2.bold())
          Text(text.progressDetail(model.progress.detail))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if let value = model.progress.liveValue, let unit = model.progress.liveUnit {
          VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.0f", value))
              .font(.title2.monospacedDigit().weight(.semibold))
            Text(unit)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      ProgressView(value: model.progress.fraction)
        .progressViewStyle(.linear)

      Label(
        text(
          "Non espellere l’unità e non scollegare il cavo.",
          "Do not eject the drive or disconnect the cable."
        ),
        systemImage: "cable.connector"
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      Button(text("Annulla in sicurezza", "Cancel safely"), systemImage: "stop.fill") {
        model.cancelTest()
      }
      .buttonStyle(.bordered)
      .frame(maxWidth: .infinity)
    }
  }

  private func completedContent(_ result: SavedBenchmark) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(text("Test completato", "Test complete"))
            .font(.title2.bold())
          Text(Formatters.duration(result.measurement.totalDurationSeconds))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Label(
          result.measurement.integrityVerified
            ? text("Dati verificati", "Data verified")
            : text("Completato", "Complete"),
          systemImage: result.measurement.integrityVerified
            ? "checkmark.shield.fill"
            : "checkmark.circle"
        )
        .font(.caption)
        .foregroundStyle(result.measurement.integrityVerified ? AppTheme.green : .secondary)
      }

      ResultMetricsGrid(result: result, text: text)

      if let writeStability = result.measurement.writeStabilityPercent,
        let readStability = result.measurement.readStabilityPercent
      {
        Text(
          text(
            "Stabilità: scrittura \(String(format: "%.0f%%", writeStability)), lettura \(String(format: "%.0f%%", readStability)).",
            "Stability: write \(String(format: "%.0f%%", writeStability)), read \(String(format: "%.0f%%", readStability))."
          )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Button {
        model.saveCurrentResult()
      } label: {
        Label(
          model.isCurrentResultSaved
            ? text("Salvato", "Saved")
            : text("Salva risultato", "Save result"),
          systemImage: model.isCurrentResultSaved
            ? "checkmark.circle.fill"
            : "externaldrive.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.isCurrentResultSaved)
      .help(
        text(
          "Salva il risultato nel database locale per confrontarlo in seguito.",
          "Save the result in the local database for later comparisons."
        )
      )

      Button(text("Esegui un altro test", "Run another test"), systemImage: "arrow.clockwise") {
        model.currentResult = nil
        model.isCurrentResultSaved = false
      }
      .buttonStyle(.plain)
      .foregroundStyle(AppTheme.accent)
      .frame(maxWidth: .infinity)
    }
  }
}
