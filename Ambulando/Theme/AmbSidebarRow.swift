import SwiftUI

/// UX lab: the one sidebar row. Home, scopes, channels and conversations all use it, so they share height, inset,
/// type, radius and a full-width hover and selection (Buzz/Linear sidebars). The leading slot holds the item's mark
/// (or, for a group, its disclosure chevron); the trailing slot holds a status (unread dot, agent working) that gives
/// way to the row's action (•••, +) while the row is hovered. Nesting indents inside the row, never outside it.
struct SidebarRow<Leading: View, Status: View, Action: View>: View {
    typealias L = Amb.SidebarLayout

    /// A group row's chevron: folds its children; the rest of the row still opens the group.
    struct Disclosure {
        var collapsed: Bool
        var accessibilityLabel: String
        var identifier: String
        var toggle: () -> Void
    }

    let label: String
    var selected = false
    var unread = false
    var level = 0
    /// Overrides the weight for a row that heads a group (scopes); selection and unread still win.
    var weight: Font.Weight? = nil
    var disclosure: Disclosure? = nil
    /// False when `rowAction` builds nothing for this row, so the status stays on hover.
    var hasRowAction = true
    var accessibilityLabel: String? = nil
    var identifier: String
    let action: () -> Void
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var status: () -> Status
    @ViewBuilder var rowAction: () -> Action

    private func mainLabel(fills: Bool) -> some View {
        HStack(spacing: L.iconGap) {
            leading().frame(width: L.iconSlot, height: L.iconSlot)
            Text(label)
                .font(.amb(.subheadline).weight(selected ? .medium : unread ? .semibold : weight ?? .regular))
                .foregroundStyle(selected || unread ? Amb.foreground : Amb.secondaryForeground)
                .lineLimit(1)
            if fills { Spacer(minLength: 0) }
        }
        .padding(.leading, L.inset + CGFloat(level) * L.indent)
        .frame(minHeight: L.rowHeight)
        .contentShape(Rectangle())
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) { mainLabel(fills: disclosure == nil) }
                .buttonStyle(.plain)
                .accessibilityLabel((accessibilityLabel ?? label) + (unread ? ", unread" : ""))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(identifier)
            if let disclosure {
                // A group's chevron sits right after its name; the rest of the row still opens the group.
                Button(action: disclosure.toggle) {
                    Image(systemName: disclosure.collapsed ? "chevron.right" : "chevron.down")
                        .font(.amb(.caption2).weight(.semibold)).foregroundStyle(Amb.faint)
                        .frame(width: 16, height: L.rowHeight).padding(.leading, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(disclosure.accessibilityLabel)
                .accessibilityIdentifier(disclosure.identifier)
                Button(action: action) { Color.clear.frame(maxWidth: .infinity, minHeight: L.rowHeight).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
            }
            SidebarRowTrailing(status: status, action: rowAction, hasAction: hasRowAction && Action.self != EmptyView.self)
                .padding(.trailing, L.inset / 2)
        }
        .background(selected ? Amb.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
        .ambHoverRow()
    }
}

extension SidebarRow where Status == EmptyView, Action == EmptyView {
    init(label: String, selected: Bool = false, level: Int = 0, identifier: String, accessibilityLabel: String? = nil,
         action: @escaping () -> Void, @ViewBuilder leading: @escaping () -> Leading) {
        self.init(label: label, selected: selected, level: level, accessibilityLabel: accessibilityLabel, identifier: identifier,
                  action: action, leading: leading, status: { EmptyView() }, rowAction: { EmptyView() })
    }
}

/// The trailing slot: the status, swapped for the action while the row is hovered (Mac). Where hover-revealed
/// controls always show (VoiceOver, Full Keyboard Access, the Mac checks), the action shows and the status is still
/// in the row's accessibility label.
private struct SidebarRowTrailing<Status: View, Action: View>: View {
    @Environment(\.ambRowHovered) private var hovered
    let status: () -> Status
    let action: () -> Action
    let hasAction: Bool

    var body: some View {
        ZStack {
            status().opacity(showsAction ? 0 : 1).accessibilityHidden(true)
            if hasAction { action().ambRevealOnHover() }
        }
        .frame(width: Amb.SidebarLayout.trailingSlot, height: Amb.SidebarLayout.rowHeight)
    }

    private var showsAction: Bool {
        guard hasAction else { return false }
        #if os(macOS)
        return hovered || AmbRevealPolicy.alwaysShow
        #else
        return true
        #endif
    }
}

/// A small icon button for a row's trailing slot (••• or +).
struct SidebarRowButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.amb(.caption).weight(.bold)).foregroundStyle(Amb.mutedForeground)
                .frame(width: Amb.SidebarLayout.trailingSlot, height: Amb.SidebarLayout.rowHeight).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ambTooltip(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

/// A section heading in the sidebar ("Solo", "Scopes"): quiet text, with an optional action (+) always shown.
struct SidebarSectionHeading<Action: View>: View {
    let text: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: 0) {
            Text(text).font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.mutedForeground)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            action().padding(.trailing, Amb.SidebarLayout.inset / 2)
        }
        .padding(.leading, Amb.SidebarLayout.inset)
        .frame(minHeight: Amb.SidebarLayout.rowHeight)
        .padding(.top, Amb.SidebarLayout.sectionGap)
        .contentShape(Rectangle())
        .ambHoverRow(fill: false)
    }
}

extension SidebarSectionHeading where Action == EmptyView {
    init(text: String) { self.init(text: text, action: { EmptyView() }) }
}

/// The unread signal in a row's status slot.
struct SidebarUnreadDot: View {
    var body: some View { Circle().fill(Amb.unread).frame(width: 6, height: 6) }
}
