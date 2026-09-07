#!/usr/bin/swift

import AppKit
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("set-file-icon: \(message)\n".utf8))
  exit(1)
}

guard CommandLine.arguments.count == 5 else {
  fail("usage: set_file_icon.swift TARGET SOURCE.png VISIBLE_SIZE FINDER_ICON_SIZE")
}

let targetPath = CommandLine.arguments[1]
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
let visibleSize = CGFloat(Double(CommandLine.arguments[3]) ?? 0)
let finderIconSize = CGFloat(Double(CommandLine.arguments[4]) ?? 0)
guard visibleSize > 0, finderIconSize > 0, visibleSize <= finderIconSize else {
  fail("invalid visible or Finder icon size")
}
guard FileManager.default.fileExists(atPath: targetPath) else {
  fail("target does not exist: \(targetPath)")
}
guard let source = NSImage(contentsOf: sourceURL) else {
  fail("cannot load icon source: \(sourceURL.path)")
}

let canvasSize = NSSize(width: 1_024, height: 1_024)
let visibleScale = visibleSize / finderIconSize
let drawingSize = NSSize(
  width: canvasSize.width * visibleScale,
  height: canvasSize.height * visibleScale
)
let drawingRect = NSRect(
  x: (canvasSize.width - drawingSize.width) / 2,
  y: 0,
  width: drawingSize.width,
  height: drawingSize.height
)

let paddedIcon = NSImage(size: canvasSize)
paddedIcon.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
source.draw(
  in: drawingRect,
  from: .zero,
  operation: .sourceOver,
  fraction: 1,
  respectFlipped: false,
  hints: [.interpolation: NSImageInterpolation.high]
)
paddedIcon.unlockFocus()

guard NSWorkspace.shared.setIcon(paddedIcon, forFile: targetPath, options: []) else {
  fail("Finder rejected the custom icon for \(targetPath)")
}
