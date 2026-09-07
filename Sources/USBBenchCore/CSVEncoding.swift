import Foundation

public enum CSVEncoding {
  public static func field(_ value: String) -> String {
    let safeValue = requiresFormulaNeutralization(value) ? "'\(value)" : value
    return "\"\(safeValue.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private static func requiresFormulaNeutralization(_ value: String) -> Bool {
    guard let first = value.unicodeScalars.first else { return false }
    return first == "="
      || first == "+"
      || first == "-"
      || first == "@"
      || first == "\t"
      || first == "\r"
  }
}
