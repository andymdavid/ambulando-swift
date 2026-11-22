import SwiftUI

#if os(macOS)
/// UX lab (Mac): the row at the top of an opened record (a task, file or document): ‹ and the section you came from,
/// where the record lives, and the record's own actions at the end. It is the one way back, so the window toolbar's
/// back arrow is hidden wherever it shows. Esc goes back too, unless the screen is editing.
struct MacRecordCrumbs<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Where the record lives, e.g. "#general".
    var place: String?
    /// A further step, e.g. "Parent: Review the native inbox".
    var detail: String? = nil
    /// Whether Esc goes back (off while editing, or where Esc belongs to an editor).
    var escape = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.amb(.caption).weight(.semibold))
                    Text(model.mode.title)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Amb.secondaryForeground)
            .ambTooltip(escape ? "Back (Esc)" : "Back")
            .keyboardShortcut(escape ? KeyboardShortcut(.escape, modifiers: []) : nil)
            .accessibilityLabel("Back to \(model.mode.title)")
            .accessibilityIdentifier("record.back")
            if let place {
                Text("/").foregroundStyle(Amb.faint)
                Text(place).foregroundStyle(Amb.mutedForeground).lineLimit(1)
            }
            if let detail {
                Text("/").foregroundStyle(Amb.faint)
                Text(detail).foregroundStyle(Amb.mutedForeground).lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .font(.amb(.footnote).weight(.medium))
        .padding(.horizontal, 20).frame(height: 40)
        .background(Amb.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 0.5) }
        .navigationBarBackButtonHidden(true)
    }
}

extension MacRecordCrumbs where Trailing == EmptyView {
    init(place: String?, detail: String? = nil, escape: Bool = true) {
        self.init(place: place, detail: detail, escape: escape) { EmptyView() }
    }
}
#endif
