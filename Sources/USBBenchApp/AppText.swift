import Foundation
import SwiftUI
import USBBenchCore

enum AppLanguage: String, CaseIterable, Identifiable {
  case italian = "it"
  case english = "en"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .italian: "Italiano"
    case .english: "English"
    }
  }

  var locale: Locale {
    Locale(identifier: rawValue)
  }
}

enum AppAppearance: String, CaseIterable, Identifiable {
  case automatic
  case light
  case dark

  var id: String { rawValue }

  var colorScheme: ColorScheme? {
    switch self {
    case .automatic: nil
    case .light: .light
    case .dark: .dark
    }
  }

  func title(_ text: AppText) -> String {
    switch self {
    case .automatic: text("Automatica", "Automatic")
    case .light: text("Chiara", "Light")
    case .dark: text("Scura", "Dark")
    }
  }
}

enum ResultKindFilter: String, CaseIterable, Identifiable {
  case all
  case cables
  case devices

  var id: String { rawValue }

  init(subjectKind: SubjectKind) {
    self = subjectKind == .cable ? .cables : .devices
  }

  func title(_ text: AppText) -> String {
    switch self {
    case .all: text("Nessuno", "None")
    case .cables: text("Cavi", "Cables")
    case .devices: text("Dispositivi", "Devices")
    }
  }

  func matches(_ subjectKind: SubjectKind) -> Bool {
    switch self {
    case .all: true
    case .cables: subjectKind == .cable
    case .devices: subjectKind == .device
    }
  }
}

enum CableSpeedClaim: String, CaseIterable, Identifiable {
  case unspecified
  case usb2
  case usb5
  case usb10
  case usb20
  case usb40

  var id: String { rawValue }

  var nominalGbps: Double? {
    switch self {
    case .unspecified: nil
    case .usb2: 0.48
    case .usb5: 5
    case .usb10: 10
    case .usb20: 20
    case .usb40: 40
    }
  }

  func title(_ text: AppText) -> String {
    switch self {
    case .unspecified:
      text("Non specificata", "Not specified")
    case .usb2:
      "USB 2.0 · 480 Mb/s"
    case .usb5:
      "USB · 5 Gb/s"
    case .usb10:
      "USB · 10 Gb/s"
    case .usb20:
      "USB · 20 Gb/s"
    case .usb40:
      "USB4 · 40 Gb/s"
    }
  }
}

struct AppText {
  let language: AppLanguage

  func callAsFunction(_ italian: String, _ english: String) -> String {
    language == .italian ? italian : english
  }

  func subject(_ value: SubjectKind) -> String {
    return switch value {
    case .device: self("Dispositivo", "Device")
    case .cable: self("Cavo", "Cable")
    }
  }

  func profile(_ value: BenchmarkProfile) -> String {
    return switch value {
    case .quick: self("Rapido", "Quick")
    case .complete: self("Completo", "Complete")
    case .single: self("Singolo", "Single")
    }
  }

  func selection(_ value: BenchmarkSelection) -> String {
    switch value {
    case .all: self("Tutti i test", "All tests")
    case .sequential: self("Lettura + scrittura sequenziale", "Sequential read + write")
    case .sequentialWrite: self("Scrittura sequenziale", "Sequential write")
    case .sequentialRead: self("Lettura sequenziale", "Sequential read")
    case .randomRead: self("Lettura casuale 4K", "4K random read")
    case .randomWrite: self("Scrittura casuale 4K", "4K random write")
    }
  }

  func stage(_ value: BenchmarkStage) -> String {
    switch value {
    case .preparing: self("Preparazione", "Preparing")
    case .sequentialWrite: self("Scrittura sequenziale", "Sequential write")
    case .sequentialRead: self("Lettura sequenziale", "Sequential read")
    case .verifying: self("Verifica dati", "Verifying data")
    case .randomRead: self("Lettura casuale 4K", "4K random read")
    case .randomWrite: self("Scrittura casuale 4K", "4K random write")
    case .cleaning: self("Pulizia", "Cleaning up")
    case .finished: self("Completato", "Finished")
    }
  }

  func progressDetail(_ value: String) -> String {
    guard language == .italian else { return value }
    if value.hasPrefix("Pass "), let range = value.range(of: " of ") {
      let pass = value[value.index(value.startIndex, offsetBy: 5)..<range.lowerBound]
      let total = value[range.upperBound...]
      return "Passaggio \(pass) di \(total)"
    }
    return switch value {
    case "Ready": "Pronto"
    case "Checking free space and permissions…": "Controllo spazio e permessi…"
    case "Rechecking free space, permissions, and the USB connection…":
      "Ricontrollo spazio, permessi e collegamento USB…"
    case "Preparing the temporary file; this phase is not measured.":
      "Preparo il file temporaneo; questa fase non viene misurata."
    case "Preparing data": "Preparo i dati"
    case "Checking data outside the timed measurement.":
      "Confronto i dati senza influenzare la velocità misurata."
    case "4K blocks, queue depth 1": "Blocchi 4K, coda singola"
    case "Removing the temporary file.": "Rimuovo il file temporaneo."
    case "Test complete.": "Test completato."
    case "Test cancelled and temporary file removed.":
      "Test annullato e file rimosso."
    case "Stopping safely after the current operation…":
      "Arresto in corso; completo l’operazione corrente…"
    default: value
    }
  }

  func connection(_ value: String?) -> String? {
    switch value {
    case "direct": self("Diretto al Mac", "Direct to Mac")
    case "hub": self("Tramite hub", "Through a hub")
    default: nil
    }
  }
}
