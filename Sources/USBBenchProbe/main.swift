import Foundation
import USBBenchCore

private struct ProbeOutput: Codable {
  let volume: VolumeMetadata
  let measurement: BenchmarkMeasurement?
}

@main
private enum USBBenchProbe {
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count >= 2 else {
      throw ProbeError.usage
    }

    let command = arguments[0]
    let target = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let metadata = SystemInspector.inspectVolume(at: target)
    let measurement: BenchmarkMeasurement?

    switch command {
    case "inspect":
      measurement = nil
    case "benchmark":
      let mebibytes = arguments.count > 2 ? Int64(arguments[2]) ?? 2_048 : 2_048
      let passes = arguments.count > 3 ? Int(arguments[3]) ?? 2 : 2
      measurement = try BenchmarkEngine.run(
        configuration: .init(
          targetDirectory: target,
          fileSizeBytes: mebibytes * 1_024 * 1_024,
          passes: passes,
          selection: .sequential,
          verifiesIntegrity: true
        )
      )
    default:
      throw ProbeError.usage
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(ProbeOutput(volume: metadata, measurement: measurement))
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
  }
}

private enum ProbeError: LocalizedError {
  case usage

  var errorDescription: String? {
    "Uso: USBBenchProbe inspect <cartella> | benchmark <cartella> [MiB] [passaggi]"
  }
}
