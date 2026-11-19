import SwiftUI
import AmbulandoCore

/// Ambulando colour tokens (light / dark). Originally copied from sol/src/ambulando-tokens.css; the UX lab palette
/// (ux/foundations) moves to neutral greys with a single accent: ink for text, accent for interaction only.
enum Amb {
    fileprivate static func dynamicUI(_ light: UInt32, _ dark: UInt32) -> PlatformColor { .dynamic(light, dark) }
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color { Color(dynamicUI(light, dark)) }

    /// Page surface. The web paints its pages, header, sidebar, chat feed and section bar with `--card` (white in
    /// light mode; `styles.css` `body { background: var(--card) }`), not with `--background`.
    static let background = dynamic(0xFFFFFF, 0x131313)
    /// sol `--background`: the recessed grey the web keeps for a few inputs and nested cards.
    static let canvas = dynamic(0xF7F7F8, 0x0E0E0E)
    static let foreground = dynamic(ChatTextPalette.foreground(false), ChatTextPalette.foreground(true))
    static let card = dynamic(0xFFFFFF, 0x1A1A1A)
    static let muted = dynamic(0xF0F0F2, 0x232323)
    static let mutedForeground = dynamic(ChatTextPalette.muted(false), ChatTextPalette.muted(true))
    /// Third text level: hints, placeholders and quiet timestamps.
    static let faint = dynamic(0x9A9CA3, 0x6E6E6E)
    /// Hairlines. Kept faint: surfaces are separated by shade first, lines second.
    static let border = dynamic(0xEBEBEE, 0x262626)
    /// A firmer line for the few places that need one (focused fields, popover edges).
    static let borderStrong = dynamic(0xDCDCE1, 0x333333)
    /// The one accent: buttons, selection controls, focus, mentions of you and unread. Never used for headings.
    static let primary = dynamic(0x6E56CF, 0x7C6AE6)
    static let primaryForeground = dynamic(0xFFFFFF, 0xFFFFFF)
    /// Headings are ink, not accent.
    static let itemHeading = foreground
    /// Soft accent fill (mention chips, selected task rows).
    static let accent = dynamic(0xF0EDFC, 0x24203A)
    static let accentForeground = dynamic(0x5A43B8, 0xC6BBFF)
    static let destructive = dynamic(0xB42318, 0xFCA59D)
    static let destructiveBackground = dynamic(0xFEECEB, 0x411710)
    static let success = dynamic(0x25613E, 0xA4D1B5)
    static let successBackground = dynamic(0xE6F2E9, 0x203D2C)
    static let warning = dynamic(0x805400, 0xF3CF80)
    static let warningBackground = dynamic(0xFFF3D6, 0x40331C)
    static let info = dynamic(0x215C85, 0xADD2F0)
    /// Web addresses in messages and documents: a clear blue, always underlined, so a link never reads as plain text.
    static let link = dynamic(ChatTextPalette.link(false), ChatTextPalette.link(true))
    static let infoBackground = dynamic(0xE8F1F9, 0x20384C)
    // Surface layers: window chrome (title bar + sidebar) is the `sidebar` surface, content sits on `background`;
    // raised floats above it; hover and selected are fills. Dark: chrome darkest (#080808), content a step lighter.
    static let sidebar = dynamic(0xF7F7F8, 0x080808)
    static let raised = dynamic(0xFFFFFF, 0x1F1F1F)
    static let hoverFill = dynamic(0xF0F0F2, 0x1C1C1C)
    /// Selected row: a grey fill with ink text (selection is shown by shade, not colour).
    static let selectedFill = dynamic(0xE9E9ED, 0x2A2A2A)
    static let selectedForeground = foreground
    /// The single unread signal, everywhere (sidebar, inbox, notifications).
    static let unread = primary
    /// Fallback monograms for people and workspaces: neutral, so avatars don't read as buttons.
    static let monogram = dynamic(0xE4E4E8, 0x2A2B30)
    static let monogramForeground = dynamic(0x3A3B40, 0xD0D1D6)
    /// Around a document's white page: a faint neutral grey in both appearances (what sits on it is drawn light too).
    static let paperSurround = Color(PlatformColor(hex: 0xF4F4F6))
    /// Ink on the white document page in both appearances.
    static let paperInk = Color(PlatformColor(hex: 0x10162B))
    /// Reserved for urgency (urgent/rock priority, a busy agent); unread uses `unread`.
    static let brandOrange = Color(PlatformColor(hex: 0xBF4D0D))
    static let brandNavy = Color(PlatformColor(hex: 0x10162B))

    static let radiusPanel: CGFloat = 10      // --radius-panel 0.625rem
    static let radiusControl: CGFloat = 6     // --radius-control 0.375rem
    static let touchTarget: CGFloat = 44      // --touch-target 2.75rem

    // Computed so they follow the app text size (`TextScale`).
    @MainActor static var editorial: Font { .amb(.title2, design: .serif).weight(.semibold) }   // --font-editorial
    @MainActor static var heading: Font { .amb(.headline) }
    @MainActor static var code: Font { .amb(.footnote, design: .monospaced) }
}

extension Amb {
    /// Segmented controls as the web's active tab (`.chat-channel-tab-item.active`): solid primary, white label.
    static func applyControlAppearance() {
        #if os(iOS)
        let control = UISegmentedControl.appearance()
        control.selectedSegmentTintColor = dynamicUI(0x6E56CF, 0x7C6AE6)          // primary
        control.setTitleTextAttributes([.foregroundColor: dynamicUI(0xFFFFFF, 0xFFFFFF)], for: .selected)   // primary-foreground
        control.setTitleTextAttributes([.foregroundColor: dynamicUI(0x1B1C1F, 0xF2F2F2)], for: .normal)     // foreground
        control.backgroundColor = dynamicUI(0xF0F0F2, 0x232323)                    // muted
        #endif
    }
}

/// Approved passage artwork on its original white backing (never recoloured or clipped).
struct PassageMark: View {
    var size: CGFloat = 32
    var body: some View {
        Image("PassageMark")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .accessibilityLabel("Ambulando")
    }
}

struct BrandHeader: View {
    var subtitle: String?
    var body: some View {
        VStack(spacing: 12) {
            PassageMark(size: 64)
            Text(Product.name).font(.amb(.largeTitle, design: .serif).weight(.semibold)).foregroundStyle(Amb.foreground)
            if let subtitle { Text(subtitle).font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.amb(.body).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Amb.touchTarget)
            .foregroundStyle(Amb.primaryForeground)
            .background(Amb.primary.opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Amb.card, in: RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous).stroke(Amb.border, lineWidth: 1))
    }
}

extension View {
    func ambCard() -> some View { modifier(CardModifier()) }
    /// Rows of a grouped list on the theme's card colour (the system grey clashes with the dark navy palette).
    func ambListRows() -> some View { listRowBackground(Amb.card) }
}

/// Inline notice using the semantic status palettes.
struct Notice: View {
    enum Tone { case info, warning, error, success }
    let tone: Tone
    let text: String

    var body: some View {
        let (fg, bg, icon): (Color, Color, String) = switch tone {
        case .info: (Amb.info, Amb.infoBackground, "info.circle")
        case .warning: (Amb.warning, Amb.warningBackground, "exclamationmark.triangle")
        case .error: (Amb.destructive, Amb.destructiveBackground, "xmark.octagon")
        case .success: (Amb.success, Amb.successBackground, "checkmark.circle")
        }
        Label(text, systemImage: icon)
            .font(.amb(.footnote))
            .foregroundStyle(fg)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}


extension Amb {
    static func taskStatus(_ state: String) -> Color {
        Color(PlatformColor(hex: (TaskState(rawValue: state) ?? .new).statusRGB))
    }
}

/// A readable label in both themes; the dot and tint share the web status palette.
struct TaskStatusBadge: View {
    let state: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Amb.taskStatus(state)).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(TaskState(rawValue: state)?.label ?? state)
        }
        .font(.amb(.caption)).foregroundStyle(Amb.foreground)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Amb.taskStatus(state).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
    }
}
