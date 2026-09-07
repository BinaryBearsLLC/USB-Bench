import AppKit
import SwiftUI

enum Branding {
  static let companyURL = URL(string: "https://binarybears.com/")!

  static let companyLogo: NSImage? = {
    guard let url = Bundle.main.url(forResource: "BinaryBears-Logo", withExtension: "png") else {
      return nil
    }
    return NSImage(contentsOf: url)
  }()
}

struct CompanyLogo: View {
  let size: CGFloat

  var body: some View {
    Group {
      if let image = Branding.companyLogo {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: "pawprint.fill")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.secondary)
          .padding(size * 0.16)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
