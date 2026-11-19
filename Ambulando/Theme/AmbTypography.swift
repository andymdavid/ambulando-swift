import SwiftUI
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// UX lab type system: Geist for interface and reading text, Geist Mono for technical strings (code, IDs, keys,
/// URLs), tabular figures throughout, and a Mac scale closer to Linear's (11/12/13/14/16/18/22/28) than the system's
/// (10/10/11/13/15/17/22/26). Every `Font.amb(_:)` style comes through here, so this file is the one switch.
/// The fonts ship in `Resources/Fonts` (SIL Open Font License, `Geist-OFL.txt`) and are registered on first use.
enum AmbTypography {
    static let family = "Geist"
    static let monoFamily = "Geist Mono"

    /// Registers the bundled Geist faces for this process once; falls back to the system font if any are missing.
    @MainActor static let registered: Bool = {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])
        let faces = urls.filter { $0.lastPathComponent.hasPrefix("Geist") }
        for url in faces { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        return !faces.isEmpty
    }()

    #if os(macOS)
    /// Mac point size for each text style at 100% text size.
    static func macSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 28
        case .title: 22
        case .title2: 18
        case .title3: 16
        case .headline: 14
        case .body: 14
        case .callout: 13
        case .subheadline: 13
        case .footnote: 12
        case .caption: 11
        case .caption2: 11
        @unknown default: 13
        }
    }
    #endif

    /// The Geist font for a text style. Headlines are semibold (medium/semibold carry emphasis, not a new face);
    /// `.monospaced` maps to Geist Mono; `.serif` and `.rounded` map to Geist (one sans everywhere).
    @MainActor static func font(_ style: Font.TextStyle, design: Font.Design?, size: CGFloat?) -> Font {
        guard registered else {
            if let size { return .system(size: size, weight: style == .headline ? .semibold : .regular, design: design) }
            return .system(style, design: design)
        }
        let name = design == .monospaced ? monoFamily : family
        #if os(macOS)
        let base = Font.custom(name, fixedSize: size ?? macSize(style))
        #else
        let base = Font.custom(name, size: size ?? UIFont.preferredFont(forTextStyle: style.uiKit).pointSize, relativeTo: style)
        #endif
        let weighted = style == .headline ? base.weight(.semibold) : base
        return weighted.monospacedDigit()
    }

    #if os(macOS)
    /// AppKit Geist (composer, document selection) at a point size and weight.
    @MainActor static func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont? {
        guard registered else { return nil }
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .traits: [NSFontDescriptor.TraitKey.weight: weight]])
        return NSFont(descriptor: descriptor, size: size)
    }
    #endif
}

#if os(iOS)
private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}
#endif
