#!/usr/bin/swift

import AppKit
import Foundation

enum RenderError: LocalizedError {
  case usage
  case invalidSize
  case cannotReadSource
  case cannotDecodeImage
  case cannotCreateBitmap
  case cannotEncodePNG

  var errorDescription: String? {
    switch self {
    case .usage:
      "Usage: xcrun swift scripts/render_sanitized_image.swift INPUT OUTPUT MAX_PIXELS [square|fit]"
    case .invalidSize:
      "MAX_PIXELS must be a positive integer."
    case .cannotReadSource:
      "The source file could not be read safely."
    case .cannotDecodeImage:
      "The sanitized source could not be decoded as an image."
    case .cannotCreateBitmap:
      "The output bitmap could not be created."
    case .cannotEncodePNG:
      "The output bitmap could not be encoded as PNG."
    }
  }
}

func sanitizedSVG(from sourceURL: URL) throws -> URL {
  let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
  let document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])

  let forbiddenElements = [
    "script",
    "foreignObject",
    "animate",
    "animateMotion",
    "animateTransform",
    "set",
    "metadata",
    "namedview",
  ]
  for name in forbiddenElements {
    for node in try document.nodes(forXPath: "//*[local-name()='\(name)']") {
      node.detach()
    }
  }

  for case let element as XMLElement in try document.nodes(forXPath: "//*") {
    for attribute in element.attributes ?? [] {
      let name = attribute.localName?.lowercased() ?? attribute.name?.lowercased() ?? ""
      let value = attribute.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let lowerValue = value.lowercased()
      let removesEventHandler = name.hasPrefix("on")
      let removesEditorMetadata = attribute.name?.hasPrefix("inkscape:") == true
        || attribute.name?.hasPrefix("sodipodi:") == true
      let removesUnsafeReference = (name == "href" || name.hasSuffix(":href"))
        && !value.isEmpty
        && !value.hasPrefix("#")
      let removesJavascript = lowerValue.contains("javascript:")
      if removesEventHandler || removesEditorMetadata || removesUnsafeReference || removesJavascript {
        element.removeAttribute(forName: attribute.name ?? name)
      }
    }
  }

  guard let root = document.rootElement() else { throw RenderError.cannotReadSource }
  root.removeAttribute(forName: "xmlns:inkscape")
  root.removeAttribute(forName: "xmlns:sodipodi")

  let temporaryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("usb-bench-sanitized-\(UUID().uuidString).svg")
  try document.xmlData(options: [.nodePrettyPrint]).write(to: temporaryURL, options: .atomic)
  return temporaryURL
}

func sourcePixelSize(_ image: NSImage) throws -> CGSize {
  if let representation = image.representations.max(by: {
    $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh
  }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
    return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
  }
  guard image.size.width > 0, image.size.height > 0 else {
    throw RenderError.cannotDecodeImage
  }
  return image.size
}

func render(sourceURL: URL, outputURL: URL, maxPixels: Int, square: Bool) throws {
  var decodedURL = sourceURL
  var temporarySVG: URL?
  if sourceURL.pathExtension.lowercased() == "svg" {
    temporarySVG = try sanitizedSVG(from: sourceURL)
    decodedURL = temporarySVG!
  }
  defer {
    if let temporarySVG {
      try? FileManager.default.removeItem(at: temporarySVG)
    }
  }

  guard let image = NSImage(contentsOf: decodedURL) else {
    throw RenderError.cannotDecodeImage
  }
  let sourceSize = try sourcePixelSize(image)
  let sourceAspect = sourceSize.width / sourceSize.height
  let canvasSize: CGSize
  if square {
    canvasSize = CGSize(width: CGFloat(maxPixels), height: CGFloat(maxPixels))
  } else if sourceAspect >= 1 {
    canvasSize = CGSize(
      width: CGFloat(maxPixels),
      height: max(CGFloat(1), (CGFloat(maxPixels) / sourceAspect).rounded())
    )
  } else {
    canvasSize = CGSize(
      width: max(CGFloat(1), (CGFloat(maxPixels) * sourceAspect).rounded()),
      height: CGFloat(maxPixels)
    )
  }

  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(canvasSize.width),
      pixelsHigh: Int(canvasSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    throw RenderError.cannotCreateBitmap
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.cgContext.clear(CGRect(origin: .zero, size: canvasSize))
  context.imageInterpolation = .high

  let padding = square ? CGFloat(maxPixels) * 0.06 : 0
  let available = CGSize(
    width: canvasSize.width - padding * 2,
    height: canvasSize.height - padding * 2
  )
  let scale = min(available.width / sourceSize.width, available.height / sourceSize.height)
  let drawnSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
  let destination = CGRect(
    x: (canvasSize.width - drawnSize.width) / 2,
    y: (canvasSize.height - drawnSize.height) / 2,
    width: drawnSize.width,
    height: drawnSize.height
  )
  image.draw(
    in: destination,
    from: .zero,
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
  )
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    throw RenderError.cannotEncodePNG
  }
  try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try png.write(to: outputURL, options: .atomic)
}

do {
  guard CommandLine.arguments.count == 4 || CommandLine.arguments.count == 5 else {
    throw RenderError.usage
  }
  guard let maxPixels = Int(CommandLine.arguments[3]), maxPixels > 0 else {
    throw RenderError.invalidSize
  }
  let mode = CommandLine.arguments.count == 5 ? CommandLine.arguments[4] : "fit"
  guard mode == "square" || mode == "fit" else { throw RenderError.usage }

  try render(
    sourceURL: URL(fileURLWithPath: CommandLine.arguments[1]),
    outputURL: URL(fileURLWithPath: CommandLine.arguments[2]),
    maxPixels: maxPixels,
    square: mode == "square"
  )
} catch {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  exit(1)
}
