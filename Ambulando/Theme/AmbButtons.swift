import SwiftUI

/// UX lab button set. Four styles replace the mix of system bordered/prominent buttons, grey chips and assorted add
/// buttons:
/// - `.ambPrimary`: filled accent, white label. One per area, for the main action.
/// - `.ambSecondary`: quiet grey fill, ink label. Everyday actions ("Lock now", "Cancel", "Duplicate").
/// - `.ambGhost`: no fill until hovered, ink label. Low-emphasis actions in toolbars and rows.
/// - `.ambIcon`: square icon button, grey glyph that turns ink on hover. Replaces accent-tinted icon buttons.
/// Destructive buttons (`role: .destructive`) keep the style but use the destructive colour for the label.
/// Heights follow `controlSize` (small = 24pt, regular = 28pt on the Mac; iPhone/iPad keep a 44pt hit area).
extension ButtonStyle where Self == AmbButtonStyle {
    static var ambPrimary: AmbButtonStyle { AmbButtonStyle(kind: .primary) }
    static var ambSecondary: AmbButtonStyle { AmbButtonStyle(kind: .secondary) }
    static var ambGhost: AmbButtonStyle { AmbButtonStyle(kind: .ghost) }
    static var ambIcon: AmbButtonStyle { AmbButtonStyle(kind: .icon) }
}

struct AmbButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, icon }
    let kind: Kind
    func makeBody(configuration: Configuration) -> some View {
        AmbButtonBody(kind: kind, configuration: configuration)
    }
}

private struct AmbButtonBody: View {
    let kind: AmbButtonStyle.Kind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.controlSize) private var controlSize
    @State private var hovered = false
    @Environment(\.ambHoverPaused) private var hoverPaused

    private var height: CGFloat {
        #if os(macOS)
        controlSize == .small || controlSize == .mini ? 24 : 28
        #else
        controlSize == .small || controlSize == .mini ? 32 : 36
        #endif
    }

    private var foreground: Color {
        switch kind {
        case .primary: Amb.primaryForeground
        case .secondary, .ghost: configuration.role == .destructive ? Amb.destructive : Amb.foreground
        case .icon: hovered || configuration.isPressed ? Amb.foreground : Amb.mutedForeground
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: Amb.primary.opacity(configuration.isPressed ? 0.85 : hovered ? 0.92 : 1)
        case .secondary: configuration.isPressed ? Amb.selectedFill : Amb.muted
        case .ghost, .icon: configuration.isPressed ? Amb.selectedFill : hovered ? Amb.hoverFill : .clear
        }
    }

    var body: some View {
        configuration.label
            .font(kind == .icon ? .amb(.subheadline) : .amb(.subheadline).weight(.medium))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .icon ? 0 : 10)
            .frame(minWidth: kind == .icon ? height : nil, minHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
            .overlay {
                if kind == .secondary && hovered && !configuration.isPressed {
                    RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous).fill(Amb.hoverFill)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
            #if os(iOS)
            .frame(minWidth: kind == .icon ? Amb.touchTarget : nil, minHeight: Amb.touchTarget)
            .contentShape(Rectangle())
            #endif
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovered = $0 && !hoverPaused }
            .onChange(of: hoverPaused) { _, paused in if paused { hovered = false } }
    }
}

extension View {
    /// `.ambIcon` when `on`, otherwise the plain style (for controls that are icon buttons only in some contexts).
    @ViewBuilder func ambIconStyle(_ on: Bool) -> some View {
        if on { buttonStyle(.ambIcon) } else { buttonStyle(.plain) }
    }
}
