import AppKit
import Foundation

enum BrandIcon {
    private static let size = NSSize(width: 16, height: 16)

    static func image(for provider: Provider, color: NSColor = .white) -> NSImage? {
        let resourceName = switch provider {
        case .claude: "ProviderIcon-claude"
        case .codex: "ProviderIcon-codex"
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "svg"),
              let source = NSImage(contentsOf: url)
        else {
            return nil
        }

        source.size = self.size
        source.isTemplate = true
        return self.tinted(source, color: color)
    }

    static func attachment(for provider: Provider, color: NSColor = .white) -> NSAttributedString {
        guard let image = self.image(for: provider, color: color) else {
            return NSAttributedString(string: provider.menuSymbol)
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -3, width: self.size.width, height: self.size.height)
        return NSAttributedString(attachment: attachment)
    }

    private static func tinted(_ image: NSImage, color: NSColor) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        defer { output.unlockFocus() }

        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        rect.fill(using: .sourceAtop)
        return output
    }
}
