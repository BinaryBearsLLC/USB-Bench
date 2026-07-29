import Darwin
import Foundation
import IOKit

public enum SystemInspector {
  public static func inspectVolume(at url: URL) -> VolumeMetadata {
    let keys: Set<URLResourceKey> = [
      .volumeNameKey,
      .volumeTotalCapacityKey,
      .volumeAvailableCapacityKey,
      .volumeIsRemovableKey,
      .volumeIsLocalKey,
      .volumeUUIDStringKey,
      .volumeLocalizedFormatDescriptionKey,
    ]
    let values = try? url.resourceValues(forKeys: keys)
    let diskInfo = diskUtilityInfo(for: url)
    let parentIdentifier = diskInfo["ParentWholeDisk"] as? String
    let deviceTreePath = diskInfo["DeviceTreePath"] as? String
    let usbConnection = inspectUSBConnection(deviceTreePath: deviceTreePath)
    let isExternal =
      bool(diskInfo["RemovableMediaOrExternalDevice"])
      ?? bool(diskInfo["Internal"]).map(!)
      ?? values?.volumeIsRemovable
      ?? false

    return VolumeMetadata(
      name: values?.volumeName
        ?? diskInfo["VolumeName"] as? String
        ?? url.lastPathComponent,
      path: url.path,
      fileSystem: diskInfo["FilesystemType"] as? String
        ?? values?.volumeLocalizedFormatDescription,
      capacityBytes: number(diskInfo["TotalSize"]) ?? values?.volumeTotalCapacity.map(Int64.init),
      availableBytes: values?.volumeAvailableCapacity.map(Int64.init),
      isRemovable: isExternal,
      isLocal: values?.volumeIsLocal ?? true,
      volumeUUID: diskInfo["VolumeUUID"] as? String ?? values?.volumeUUIDString,
      deviceIdentifier: diskInfo["DeviceIdentifier"] as? String,
      mediaName: usbConnection?.productName
        ?? nonEmptyString(diskInfo["MediaName"])
        ?? nonEmptyString(diskInfo["IORegistryEntryName"]),
      busProtocol: nonEmptyString(diskInfo["BusProtocol"])
        ?? nonEmptyString(diskInfo["Protocol"]),
      isSolidState: bool(diskInfo["SolidState"]),
      parentWholeDisk: parentIdentifier,
      negotiatedSpeed: usbConnection?.speed
        ?? speedDescription(from: diskInfo),
      connectionKind: usbConnection.map { $0.viaHub ? "hub" : "direct" }
    )
  }

  public static func hostMetadata() -> HostMetadata {
    let version =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "1.0.0"
    return HostMetadata(
      model: sysctlString("hw.model") ?? "Mac",
      architecture: machineArchitecture(),
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      appVersion: version
    )
  }

  private static func diskUtilityInfo(for url: URL) -> [String: Any] {
    diskUtilityInfo(for: url.path)
  }

  private static func diskUtilityInfo(for target: String) -> [String: Any] {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
    process.arguments = ["info", "-plist", target]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return [:] }
      let data = output.fileHandleForReading.readDataToEndOfFile()
      return
        (try PropertyListSerialization.propertyList(
          from: data,
          options: [],
          format: nil
        )) as? [String: Any] ?? [:]
    } catch {
      return [:]
    }
  }

  private struct USBConnection {
    let speed: String?
    let viaHub: Bool
    let productName: String?
  }

  private static func inspectUSBConnection(deviceTreePath: String?) -> USBConnection? {
    guard let locationID = locationID(from: deviceTreePath),
      let matching = IOServiceMatching("IOUSBHostDevice")
    else {
      return nil
    }

    var iterator: io_iterator_t = 0
    guard
      IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        == KERN_SUCCESS
    else {
      return nil
    }
    defer { IOObjectRelease(iterator) }

    while true {
      let service = IOIteratorNext(iterator)
      guard service != 0 else { break }
      defer { IOObjectRelease(service) }

      guard propertyNumber(service, key: "locationID")?.uint32Value == locationID else {
        continue
      }
      let bitsPerSecond = propertyNumber(service, key: "UsbLinkSpeed")?.int64Value
      return USBConnection(
        speed: bitsPerSecond.flatMap(formatLinkSpeed),
        viaHub: hasUSBHubAncestor(service),
        productName: propertyString(service, key: "USB Product Name")
          ?? propertyString(service, key: "kUSBProductString")
      )
    }
    return nil
  }

  private static func locationID(from path: String?) -> UInt32? {
    guard let path,
      let suffix = path.split(separator: "@").last
    else {
      return nil
    }
    let hex = suffix.prefix { $0.isHexDigit }
    return UInt32(hex, radix: 16)
  }

  private static func hasUSBHubAncestor(_ service: io_registry_entry_t) -> Bool {
    var current = service
    var ownsCurrent = false
    defer {
      if ownsCurrent {
        IOObjectRelease(current)
      }
    }

    while true {
      var parent: io_registry_entry_t = 0
      guard
        IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
          == KERN_SUCCESS
      else {
        return false
      }
      if ownsCurrent {
        IOObjectRelease(current)
      }
      current = parent
      ownsCurrent = true

      if propertyNumber(current, key: "bDeviceClass")?.intValue == 9 {
        return true
      }
      let productName =
        propertyString(current, key: "USB Product Name")
        ?? propertyString(current, key: "kUSBProductString")
      if productName?.localizedCaseInsensitiveContains("hub") == true {
        return true
      }
    }
  }

  private static func propertyNumber(
    _ entry: io_registry_entry_t,
    key: String
  ) -> NSNumber? {
    IORegistryEntryCreateCFProperty(
      entry,
      key as CFString,
      kCFAllocatorDefault,
      0
    )?.takeRetainedValue() as? NSNumber
  }

  private static func propertyString(
    _ entry: io_registry_entry_t,
    key: String
  ) -> String? {
    IORegistryEntryCreateCFProperty(
      entry,
      key as CFString,
      kCFAllocatorDefault,
      0
    )?.takeRetainedValue() as? String
  }

  private static func formatLinkSpeed(_ bitsPerSecond: Int64) -> String? {
    guard bitsPerSecond > 0 else { return nil }
    if bitsPerSecond >= 1_000_000_000 {
      let gbps = Double(bitsPerSecond) / 1_000_000_000
      return gbps.rounded() == gbps
        ? "\(Int(gbps)) Gb/s"
        : String(format: "%.1f Gb/s", gbps)
    }
    let mbps = Double(bitsPerSecond) / 1_000_000
    return mbps.rounded() == mbps
      ? "\(Int(mbps)) Mb/s"
      : String(format: "%.1f Mb/s", mbps)
  }

  private static func speedDescription(from info: [String: Any]) -> String? {
    let candidateKeys = [
      "USBDeviceSpeed",
      "LinkSpeed",
      "NegotiatedLinkSpeed",
      "DeviceSpeed",
    ]
    for key in candidateKeys {
      if let value = info[key] as? String, !value.isEmpty {
        return value
      }
      if let value = number(info[key]), value > 0 {
        return "\(value)"
      }
    }
    return nil
  }

  private static func number(_ value: Any?) -> Int64? {
    (value as? NSNumber)?.int64Value
  }

  private static func bool(_ value: Any?) -> Bool? {
    (value as? NSNumber)?.boolValue
  }

  private static func nonEmptyString(_ value: Any?) -> String? {
    guard let string = value as? String, !string.isEmpty else { return nil }
    return string
  }

  private static func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
      return nil
    }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else {
      return nil
    }
    return String(cString: bytes)
  }

  private static func machineArchitecture() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
  }
}
