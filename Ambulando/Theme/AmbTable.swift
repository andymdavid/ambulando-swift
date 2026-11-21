import SwiftUI

#if os(macOS)
/// UX lab (Mac): the table pattern shared by Tasks and Docs (after gr8r-studio's task list): a toolbar of search, sort
/// and group menus; a labels row; group rows (fold, mark, name, count, optional +); one-line rows with a tick box,
/// edge-to-edge rules, full-width hover and selected fills, and a ••• menu that right-click repeats; and a bar that
/// floats at the bottom while rows are ticked.
enum AmbTable {
    /// Left of a row's tick box (room for a drag handle); group rows and labels start here too.
    static let gutter: CGFloat = Amb.ListLayout.dragMargin
    /// From the tick box to a row's title: past the group's name, so a row reads as inside its group.
    static let titleIndent: CGFloat = 48
}

/// A table row's hover and selected fills and the hairline under it, all edge to edge, so the fills sit flush between
/// the rules and a group's last row is closed off too (gr8r-studio).
struct AmbTableRule: ViewModifier {
    var selected = false
    func body(content: Content) -> some View {
        content
            .background(selected ? Amb.selectedFill : .clear)
            .ambHoverRow(radius: 0)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Amb.border).frame(height: 1).accessibilityHidden(true)
            }
    }
}

/// The ••• menu's items as a SwiftUI menu, for right-click.
struct AmbTableMenuItems: View {
    let items: [NativeMessageAction]
    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            if item.children.isEmpty {
                Button { item.perform?() } label: { label(item) }
            } else {
                Menu { AmbTableMenuItems(items: item.children) } label: { label(item) }
            }
        }
    }
    @ViewBuilder private func label(_ item: NativeMessageAction) -> some View {
        if item.symbol.isEmpty { Text(item.title) } else { Label(item.title, systemImage: item.symbol) }
    }
}

/// A square tick box in the accent when ticked (selection is an interaction: the accent's job).
struct AmbTableCheckbox: View {
    enum State { case off, on, mixed }
    let state: State
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(state == .off ? Color.clear : Amb.primary)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Amb.borderStrong : .clear, lineWidth: 1.25)
                if state == .on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Amb.primaryForeground) }
                if state == .mixed { Capsule().fill(Amb.primaryForeground).frame(width: 8, height: 2) }
            }
            .frame(width: 16, height: 16)
            .opacity(enabled ? 1 : 0.4)
            .frame(width: 16, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(state == .on ? "Selected" : state == .mixed ? "Some selected" : "Not selected")
    }
}

/// A group row: fold chevron, mark, name and count, an optional + (new item in this group), and a rule under it.
struct AmbTableGroupRow<Mark: View>: View {
    let id: String
    let title: String
    let count: Int
    let closed: Bool
    let toggle: () -> Void
    var addHelp: String? = nil
    var add: (() -> Void)? = nil
    @ViewBuilder let mark: () -> Mark

    var body: some View {
        HStack(spacing: Amb.Space.s) {
            Button(action: toggle) {
                Image(systemName: closed ? "chevron.right" : "chevron.down").font(.amb(.caption).weight(.semibold))
                    .foregroundStyle(Amb.mutedForeground).frame(width: 16, height: 16).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(closed ? "Show" : "Hide") \(title)")
            .accessibilityIdentifier("table.group.toggle.\(id)")
            mark()
            Text(title).font(.amb(.subheadline).weight(.semibold)).foregroundStyle(Amb.foreground)
            Text("\(count)").font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground).monospacedDigit()
            if let add {
                Button(action: add) {
                    Image(systemName: "plus").font(.amb(.caption).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain).ambHover()
                .ambTooltip(addHelp ?? "New")
                .accessibilityIdentifier("table.group.new.\(id)")
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, AmbTable.gutter).padding(.trailing, Amb.ListLayout.trailing)
        .padding(.top, Amb.ListLayout.sectionTop).padding(.bottom, Amb.Space.s)
        // Rules run edge to edge, so hover and selected fills sit flush between them.
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The floating bar for ticked rows: "N selected", the actions, and ✕ to clear.
struct AmbBulkBar<Actions: View>: View {
    let count: Int
    let identifier: String
    let clear: () -> Void
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: 2) {
            Text("\(count) selected").font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.foreground)
                .monospacedDigit().padding(.horizontal, 10)
            AmbBulkBarDivider()
            actions()
            AmbBulkBarDivider()
            Button(action: clear) { Image(systemName: "xmark") }
                .buttonStyle(.ambIcon).ambTooltip("Clear selection (Esc)")
                .accessibilityLabel("Clear selection").accessibilityIdentifier("\(identifier).clear")
        }
        .font(.amb(.footnote))
        .padding(6)
        .background(Amb.raised, in: RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous).stroke(Amb.borderStrong))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bulk actions")
        .accessibilityIdentifier(identifier)
    }
}

struct AmbBulkBarDivider: View {
    var body: some View { Rectangle().fill(Amb.border).frame(width: 1, height: 18).padding(.horizontal, 4) }
}

/// A menu in the bulk bar (Status, Assignee…).
struct AmbBulkBarMenu<Items: View>: View {
    let title: String
    let symbol: String
    let identifier: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu { items() } label: { Label(title, systemImage: symbol).font(.amb(.footnote).weight(.medium)) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .tint(Amb.secondaryForeground).foregroundStyle(Amb.secondaryForeground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .ambHover()
            .accessibilityIdentifier(identifier)
    }
}

/// The toolbar's search field.
struct AmbTableSearchField: View {
    let prompt: String
    @Binding var text: String
    let identifier: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Amb.mutedForeground).accessibilityHidden(true)
            TextField(prompt, text: $text).textFieldStyle(.plain).accessibilityIdentifier(identifier)
        }
        .font(.amb(.footnote))
        .padding(.horizontal, 10).frame(width: 240, height: 28)
        .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(Amb.border))
    }
}

/// A toolbar menu reading "Sort: Updated" or "Group: Status", with the choices ticked.
struct AmbTableToolbarMenu<Value: Hashable>: View {
    let symbol: String
    let title: String
    let values: [Value]
    let label: (Value) -> String
    @Binding var selection: Value
    let identifier: String

    var body: some View {
        // One label: a borderless Mac menu keeps only its first text, and tints its icon with the accent.
        Menu {
            ForEach(values, id: \.self) { value in
                Button { selection = value } label: {
                    if selection == value { Label(label(value), systemImage: "checkmark") } else { Text(label(value)) }
                }
            }
        } label: {
            Label { Text(title + ": " + label(selection)) } icon: { Image(systemName: symbol) }
                .font(.amb(.footnote).weight(.medium))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(Amb.secondaryForeground)
        .foregroundStyle(Amb.secondaryForeground)
        .accessibilityIdentifier(identifier)
    }
}
#endif
