import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("Uso: make_icon.swift output.png\n".utf8))
  exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
  FileHandle.standardError.write(Data("Contesto grafico non disponibile\n".utf8))
  exit(3)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let outerRect = NSRect(x: 28, y: 28, width: 968, height: 968)
let outerPath = NSBezierPath(
  roundedRect: outerRect,
  xRadius: 220,
  yRadius: 220
)
outerPath.addClip()

let background = NSGradient(colors: [
  NSColor(calibratedRed: 0.08, green: 0.25, blue: 0.78, alpha: 1),
  NSColor(calibratedRed: 0.20, green: 0.49, blue: 0.98, alpha: 1),
  NSColor(calibratedRed: 0.10, green: 0.73, blue: 0.86, alpha: 1),
])!
background.draw(in: outerPath, angle: -48)

NSColor.white.withAlphaComponent(0.11).setFill()
NSBezierPath(ovalIn: NSRect(x: 170, y: 210, width: 690, height: 690)).fill()

let arc = NSBezierPath()
arc.appendArc(
  withCenter: NSPoint(x: 512, y: 545),
  radius: 264,
  startAngle: 28,
  endAngle: 152,
  clockwise: false
)
arc.lineWidth = 44
arc.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.92).setStroke()
arc.stroke()

for angle in stride(from: 38.0, through: 142.0, by: 13.0) {
  let radians = angle * .pi / 180
  let inner = NSPoint(
    x: 512 + cos(radians) * 213,
    y: 545 + sin(radians) * 213
  )
  let outer = NSPoint(
    x: 512 + cos(radians) * 246,
    y: 545 + sin(radians) * 246
  )
  let tick = NSBezierPath()
  tick.move(to: inner)
  tick.line(to: outer)
  tick.lineWidth = 13
  tick.lineCapStyle = .round
  NSColor.white.withAlphaComponent(0.66).setStroke()
  tick.stroke()
}

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 512, y: 545))
needle.line(to: NSPoint(x: 663, y: 682))
needle.lineWidth = 30
needle.lineCapStyle = .round
NSColor.white.setStroke()
needle.stroke()
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: 476, y: 509, width: 72, height: 72)).fill()

if let symbol = NSImage(
  systemSymbolName: "cable.connector.horizontal",
  accessibilityDescription: nil
)?.withSymbolConfiguration(
  NSImage.SymbolConfiguration(pointSize: 282, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
) {
  let symbolRect = NSRect(x: 231, y: 176, width: 562, height: 260)
  symbol.draw(
    in: symbolRect,
    from: .zero,
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
  )
}

let highlight = NSBezierPath(
  roundedRect: outerRect.insetBy(dx: 15, dy: 15),
  xRadius: 205,
  yRadius: 205
)
highlight.lineWidth = 10
NSColor.white.withAlphaComponent(0.18).setStroke()
highlight.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  FileHandle.standardError.write(Data("Impossibile creare il PNG\n".utf8))
  exit(4)
}

try png.write(to: outputURL, options: .atomic)
