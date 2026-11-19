import SwiftUI

/// UX lab hover system. Rows, tabs and buttons answer the pointer with a quiet `Amb.hoverFill`, and secondary row
/// actions (•••) appear only while the row is hovered, as in Linear. Selected rows keep their own fill: apply
/// `ambHover` after (outside) the selected background, so the selection draws on top.
///
/// Reveal-on-hover applies on the Mac only. On iPhone and iPad (touch, and UI tests that need hittable controls)
/// row actions stay visible; iPad with a pointer still gets the hover fill.
extension View {
    /// A hover fill behind this view, in a rounded rectangle.
    func ambHover(radius: CGFloat = Amb.radiusControl) -> some View { modifier(AmbHoverFill(radius: radius)) }

    /// Tracks hover over a whole row (fill included) and tells `ambRevealOnHover` descendants.
    func ambHoverRow(radius: CGFloat = Amb.radiusControl) -> some View { modifier(AmbHoverRow(radius: radius)) }

    /// Shows this view only while its `ambHoverRow` is hovered (Mac only). It stays in the accessibility tree and keeps
    /// its hit area, so VoiceOver and clicks on the spot still work.
    func ambRevealOnHover() -> some View { modifier(AmbRevealOnHover()) }
}

private struct AmbHoverFill: ViewModifier {
    let radius: CGFloat
    @Environment(\.ambInHoverRow) private var inHoverRow
    @State private var hovered = false
    func body(content: Content) -> some View {
        // Inside an `ambHoverRow` the row draws the one fill; a second translucent layer would double up.
        if inHoverRow {
            content
        } else {
            content
                .background(hovered ? Amb.hoverFill : Color.clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { hovered = $0 }
        }
    }
}

private struct AmbHoverRow: ViewModifier {
    let radius: CGFloat
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .environment(\.ambRowHovered, hovered)
            .environment(\.ambInHoverRow, true)
            .background(hovered ? Amb.hoverFill : Color.clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onHover { hovered = $0 }
    }
}

private struct AmbRevealOnHover: ViewModifier {
    @Environment(\.ambRowHovered) private var rowHovered
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .opacity(rowHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: rowHovered)
        #else
        content
        #endif
    }
}

private struct AmbRowHoveredKey: EnvironmentKey { static let defaultValue = false }
private struct AmbInHoverRowKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var ambRowHovered: Bool {
        get { self[AmbRowHoveredKey.self] }
        set { self[AmbRowHoveredKey.self] = newValue }
    }
    var ambInHoverRow: Bool {
        get { self[AmbInHoverRowKey.self] }
        set { self[AmbInHoverRowKey.self] = newValue }
    }
}
